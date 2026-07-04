output "bastion_public_ip" {
  value = module.ec2.public_ips["bastion-server"]
}

output "monitoring_private_ip" {
  value = module.ec2.private_ips["monitoring-server"]
}

output "app_server_1_private_ip" {
  value = module.ec2.private_ips["app-server-1"]
}

output "app_server_2_private_ip" {
  value = module.ec2.private_ips["app-server-2"]
}
