provider "aws" {
  version = "2.18.0"
  region  = "us-east-2"
}



module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v2.7.0"

  name = "jenkins"
  cidr = var.vpc_cidr

  azs                  = var.vpc_azs
  private_subnets      = var.vpc_private_subnets
  public_subnets       = var.vpc_public_subnets
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
  enable_vpn_gateway   = false

  tags = var.tags
}

data "aws_ami" "image" {
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_efs_file_system" "main" {
  tags = var.tags
}

resource "aws_efs_mount_target" "main" {
  count = length(module.vpc.azs)

  file_system_id = aws_efs_file_system.main.id
  subnet_id      = module.vpc.public_subnets[count.index]

  security_groups = [
    aws_security_group.efs.id
  ]
}

resource "aws_security_group" "efs" {
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

resource "aws_iam_instance_profile" "instance_profile" {
  role = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource "aws_iam_role_policy" "jenkins" {
  name   = "jenkins-cluster-node"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.jenkins.json
}

data "aws_iam_policy_document" "jenkins" {
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

resource "aws_instance" "jenkins" {
  count                  = length(module.vpc.azs)
  availability_zone      = module.vpc.azs[count.index]
  ami                    = data.aws_ami.image.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.name
  subnet_id              = module.vpc.public_subnets[count.index]
  vpc_security_group_ids = [module.vpc.default_security_group_id]
  key_name               = var.key_name
  tags                   = merge(var.tags, { "Name" = var.cluster_name })
  user_data              = templatefile("${path.module}/scripts/jenkins.sh", { "efs_fqdn" = aws_efs_mount_target.main.0.dns_name, "eip" = aws_eip.lb.public_ip, "eip_allocation" = aws_eip.lb.id, "user" = var.jenkins_user, "password" = var.jenkins_password, "cluster_name" = var.cluster_name })
}

resource "aws_eip" "lb" {}
