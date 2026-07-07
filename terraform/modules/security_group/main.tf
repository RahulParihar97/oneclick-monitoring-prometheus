resource "aws_security_group" "bastion" {

  name        = "bastion-sg"
  description = "Bastion Security Group"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"

    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP"

    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {

    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "bastion-sg"
  }

}

################################################################################

resource "aws_security_group" "app" {

  name   = "app-sg"
  vpc_id = var.vpc_id

  ingress {

    description = "SSH from Bastion"

    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    security_groups = [
      aws_security_group.bastion.id
    ]

  }

  ingress {

    description = "SSH from Monitoring"

    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    security_groups = [
      aws_security_group.monitoring.id
    ]

  }

  ingress {

    description = "Node Exporter"

    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"

    security_groups = [
      aws_security_group.monitoring.id
    ]

  }

  egress {

    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "app-sg"
  }

}

################################################################################

resource "aws_security_group" "monitoring" {

  name   = "monitoring-sg"
  vpc_id = var.vpc_id

  ####################################################
  # SSH from Bastion
  ####################################################

  ingress {

    description = "SSH from Bastion"

    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    security_groups = [
      aws_security_group.bastion.id
    ]

  }

  ####################################################
  # Prometheus (Public for Demo)
  ####################################################

  ingress {

    description = "Prometheus"

    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  ####################################################
  # Grafana (Public for Demo)
  ####################################################

  ingress {

    description = "Grafana"

    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {

    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "monitoring-sg"
  }

}
