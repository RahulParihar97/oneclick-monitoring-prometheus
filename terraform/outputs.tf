output "bastion_public_ip" {
  value = aws_instance.this["bastion-server"].public_ip
}

output "app_server_1_private_ip" {
  value = aws_instance.this["app-server-1"].private_ip
}

output "app_server_2_private_ip" {
  value = aws_instance.this["app-server-2"].private_ip
}

output "monitoring_private_ip" {
  value = aws_instance.this["monitoring-server"].private_ip
}
