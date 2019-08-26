output "public_dns" {
  value = "http://${aws_eip.lb.public_dns}:8080"
}
