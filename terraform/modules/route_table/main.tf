resource "aws_route_table" "public" {

  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }

  tags = {
    Name = "Public-RT"
  }

}

resource "aws_route_table_association" "public" {

  for_each = var.public_subnet_ids

  subnet_id = each.value

  route_table_id = aws_route_table.public.id

}

resource "aws_route_table" "private" {

  vpc_id = var.vpc_id

  route {

    cidr_block = "0.0.0.0/0"

    nat_gateway_id = var.nat_gateway_id

  }

  tags = {
    Name = "Private-RT"
  }

}

resource "aws_route_table_association" "private" {

  for_each = var.private_subnet_ids

  subnet_id = each.value

  route_table_id = aws_route_table.private.id

}
