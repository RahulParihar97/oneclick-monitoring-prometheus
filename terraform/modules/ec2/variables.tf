variable "key_name" {
  type = string
}

variable "instances" {

  type = map(object({

    ami_type            = string
    instance_type       = string
    subnet_id           = string
    security_group_id   = string
    associate_public_ip = bool

    tags = map(string)

  }))

}
variable "instance_profile_name" {
  type = string
}
