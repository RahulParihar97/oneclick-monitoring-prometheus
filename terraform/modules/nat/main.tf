resource "aws_eip" "this" {

  domain = "vpc"

  tags = {
    Name = "${var.nat_name}-eip"
  }

}

resource "aws_nat_gateway" "this" {

  allocation_id = aws_eip.this.id

  subnet_id = var.public_subnet_id

  tags = {
    Name = var.nat_name
  }

  depends_on = [
    aws_eip.this
  ]

}
