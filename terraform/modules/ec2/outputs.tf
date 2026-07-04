output "public_ips" {

  value = {

    for k, v in aws_instance.this :

    k => v.public_ip

  }

}

output "private_ips" {

  value = {

    for k, v in aws_instance.this :

    k => v.private_ip

  }

}
