output "bastion_public_ip" {
  value = module.ec2.public_ips["bastion-server"]
}

output "app_server_1_private_ip" {
  value = module.ec2.private_ips["app-server-1"]
}

output "app_server_2_private_ip" {
  value = module.ec2.private_ips["app-server-2"]
}

output "monitoring_private_ip" {
  value = module.ec2.private_ips["monitoring-server"]
}
output "monitoring_public_ip" {

  description = "Public IP of Monitoring Server"

  value = module.ec2.public_ips["monitoring-server"]

}
output "instance_ids" {
  value = module.ec2.instance_ids
}
