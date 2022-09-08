output "principal_urls" {
    value = aws_instance.principal_instance[*].public_ip
}