variable "cluster_name" { default = "jenkins" }
variable "key_name" {}
variable "jenkins_password" {}
variable "jenkins_user" {}
variable "consul_cluster_size" { default = 3 }
variable "consul_cluster_name" { default = "consul" }
variable "vpc_azs" {
  default = ["us-east-2a", "us-east-2b", "us-east-2c"]
}
variable "vpc_private_subnets" {
  default = ["192.168.168.0/27", "192.168.168.32/27", "192.168.168.64/27"]
}
variable "vpc_public_subnets" {
  default = ["192.168.168.96/27", "192.168.168.128/27", "192.168.168.160/27"]
}
variable "vpc_cidr" { default = "192.168.168.0/24" }
variable "ami_id" {}
variable "instance_type" { default = "t3.medium" }
variable "tags" {
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}

