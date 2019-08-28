provider aws {
  version = "2.18.0"
  region  = "us-east-2"
}

module vpc {
  source = "terraform-aws-modules/vpc/aws"

  name                             = "jenkins"
  cidr                             = var.vpc_cidr
  azs                              = var.azs
  public_subnets                   = var.subnets
  map_public_ip_on_launch          = false
  enable_ec2_endpoint              = true
  ec2_endpoint_private_dns_enabled = true
  ec2_endpoint_security_group_ids  = [module.vpc.vpc_id]
  ec2_endpoint_subnet_ids          = module.vpc.public_subnets
  enable_dns_hostnames             = true
  enable_dns_support               = true
  create_vpc                       = true
  tags                             = var.tags
}

data aws_caller_identity current {}

data aws_ami controller {
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
  owners = [data.aws_caller_identity.current.account_id]
}

resource aws_efs_file_system main {
  tags = var.tags
}

resource aws_efs_mount_target main {
  count = length(module.vpc.azs)

  file_system_id = aws_efs_file_system.main.id
  subnet_id      = module.vpc.public_subnets[count.index]

  security_groups = [
    aws_security_group.efs.id
  ]
}

resource aws_security_group efs {
  name        = "efs"
  description = "Allows NFS traffic from instances within the VPC."
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    description = "NFS traffic within VPC."
    cidr_blocks = [
      module.vpc.vpc_cidr_block
    ]
  }

  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    description = "NFS traffic within VPC."
    cidr_blocks = [
      module.vpc.vpc_cidr_block
    ]
  }

  tags = var.tags
}

resource aws_iam_instance_profile instance_profile {
  role = aws_iam_role.instance_role.name
}

resource aws_iam_role instance_role {
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data aws_iam_policy_document instance_role {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource aws_iam_role_policy jenkins {
  name   = "jenkins-cluster-node"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.jenkins.json
}

data aws_iam_policy_document jenkins {
  statement {
    effect = "Allow"

    actions = [
      "ec2:AssociateAddress",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DisassociateAddress",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }
}

resource aws_network_interface jenkins {
  count           = length(module.vpc.azs)
  subnet_id       = module.vpc.public_subnets[count.index]
  private_ips     = [cidrhost(var.subnets[count.index], "10")]
  security_groups = [module.vpc.default_security_group_id]
}

resource aws_launch_template jenkins {
  count         = length(module.vpc.azs)
  name          = "jenkins${count.index}"
  image_id      = data.aws_ami.controller.id
  instance_type = var.instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }
  network_interfaces {
    associate_public_ip_address = false
    network_interface_id        = aws_network_interface.jenkins[count.index].id
  }

  key_name = var.key_name
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { "Name" = var.cluster_name })
  }
  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", { "EFS_ENDPOINT" = aws_efs_mount_target.main.0.dns_name, "ELASTIC_IP" = aws_eip.lb.public_ip, "ELASTIC_IP_ALLOCATION" = aws_eip.lb.id, "JENKINS_HOME" = "/mnt/jenkins", "NODELIST" = join("\n", [for ip in aws_network_interface.jenkins : "node: {\nring0_addr: ${ip.private_ip}\n}"]), "CLUSTER_SIZE" = length(aws_network_interface.jenkins) }))
}

resource aws_eip lb {
  tags = merge(var.tags, { "Name" = "LB" })
}

resource aws_ec2_fleet jenkins {
  count               = length(module.vpc.azs)
  terminate_instances = true
  launch_template_config {
    launch_template_specification {
      launch_template_id = aws_launch_template.jenkins[count.index].id
      version            = aws_launch_template.jenkins[count.index].latest_version
    }
  }
  type = "maintain"
  target_capacity_specification {
    default_target_capacity_type = "on-demand"
    total_target_capacity        = 1
  }
}

resource aws_lb_target_group main {
  name        = var.cluster_name
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check {
    path                = "/login"
    interval            = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
    timeout             = 5
    matcher             = "200,301,307"
  }
  stickiness {
    type    = "lb_cookie"
    enabled = false
  }
}

resource aws_lb_target_group_attachment main {
  count            = length(module.vpc.azs)
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_network_interface.jenkins[count.index].private_ip
}

resource aws_lb main {
  name               = var.cluster_name
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
}

resource aws_lb_listener main {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
