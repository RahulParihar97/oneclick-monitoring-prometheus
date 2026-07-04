module "vpc" {

  source = "./modules/vpc"

  vpc_cidr = "10.0.0.0/16"
  vpc_name = "Monitoring-VPC"

}

module "subnet" {

  source = "./modules/subnet"

  vpc_id = module.vpc.vpc_id

  subnets = {

    public-a = {
      cidr = "10.0.1.0/24"
      az   = "ap-south-1a"
      type = "public"
    }

    public-b = {
      cidr = "10.0.2.0/24"
      az   = "ap-south-1b"
      type = "public"
    }

    private-a = {
      cidr = "10.0.3.0/24"
      az   = "ap-south-1a"
      type = "private"
    }

    private-b = {
      cidr = "10.0.4.0/24"
      az   = "ap-south-1b"
      type = "private"
    }

  }

}
module "igw" {

  source = "./modules/igw"

  vpc_id = module.vpc.vpc_id

  igw_name = "Monitoring-IGW"

}

module "nat" {

  source = "./modules/nat"

  public_subnet_id = module.subnet.subnet_ids["public-a"]

  nat_name = "Monitoring-NAT"

}

module "route_table" {

  source = "./modules/route_table"

  vpc_id         = module.vpc.vpc_id
  igw_id         = module.igw.igw_id
  nat_gateway_id = module.nat.nat_gateway_id

  public_subnet_ids = {
    public-a = module.subnet.subnet_ids["public-a"]
    public-b = module.subnet.subnet_ids["public-b"]
  }

  private_subnet_ids = {
    private-a = module.subnet.subnet_ids["private-a"]
    private-b = module.subnet.subnet_ids["private-b"]
  }

}


module "security_group" {

  source = "./modules/security_group"

  vpc_id = module.vpc.vpc_id

  my_ip = var.my_ip

}
module "iam" {

  source = "./modules/iam"

  role_name = "prometheus-monitoring-role"

}
module "ec2" {

  source = "./modules/ec2"

  key_name = var.key_name

  instance_profile_name = module.iam.instance_profile_name

  instances = {

    bastion-server = {

      ami_type = "ubuntu"

      instance_type = "t3.micro"

      subnet_id = module.subnet.subnet_ids["public-a"]

      security_group_id = module.security_group.bastion_sg_id

      associate_public_ip = true

      tags = {

        Name = "bastion-server"

        OS = "ubuntu"

        Role = "bastion"

      }

    }

    app-server-1 = {

      ami_type = "ubuntu"

      instance_type = "t3.micro"

      subnet_id = module.subnet.subnet_ids["private-a"]

      security_group_id = module.security_group.app_sg_id

      associate_public_ip = false

      tags = {

        Name = "app-server-1"

        OS = "ubuntu"

        Role = "node_exporter"

      }

    }

    app-server-2 = {

      ami_type = "ubuntu"

      instance_type = "t3.micro"

      subnet_id = module.subnet.subnet_ids["private-b"]

      security_group_id = module.security_group.app_sg_id

      associate_public_ip = false

      tags = {

        Name = "app-server-2"

        OS = "ubuntu"

        Role = "node_exporter"

      }

    }

    monitoring-server = {

      ami_type = "ubuntu"

      instance_type = "t3.micro"

      subnet_id = module.subnet.subnet_ids["private-a"]

      security_group_id = module.security_group.monitoring_sg_id

      associate_public_ip = false

      tags = {

        Name = "monitoring-server"

        OS = "monitoring"

        Role = "monitoring"

      }

    }

  }

}
resource "local_file" "ssh_config" {

  filename = "/home/rahul/.ssh/config"

  content = templatefile("${path.module}/templates/ssh_config.tpl", {

    bastion_ip = module.ec2.public_ips["bastion-server"]

    app1_private_ip = module.ec2.private_ips["app-server-1"]

    app2_private_ip = module.ec2.private_ips["app-server-2"]

    monitoring_private_ip = module.ec2.private_ips["monitoring-server"]

    pem_path = "/home/rahul/roles-project/ansible-demo.pem"

  })

}
