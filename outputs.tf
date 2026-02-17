output "instance_id" {
  value = aws_instance.portfolio.id
}

output "public_ip" {
  value = var.attach_eip ? var.eip_public_ip : aws_instance.portfolio.public_ip
}

output "name" {
  value = aws_instance.portfolio.tags["Name"]
}
