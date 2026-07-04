resource "aws_instance" "this" {

  for_each = var.instances

  ami = data.aws_ami.ubuntu.id

  instance_type = each.value.instance_type

  subnet_id = each.value.subnet_id

  key_name = var.key_name

  associate_public_ip_address = each.value.associate_public_ip

  iam_instance_profile = each.key == "monitoring-server" ? var.instance_profile_name : null

  user_data = file("${path.root}/user-data/ubuntu.sh")

  vpc_security_group_ids = [
    each.value.security_group_id
  ]

  tags = each.value.tags

}
