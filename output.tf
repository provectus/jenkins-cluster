output jenkins_eip_url {
  value = "http://${aws_eip.lb.public_dns}:8080"
}

output jenkins_alb_url {
  value = aws_lb.main.dns_name
}
