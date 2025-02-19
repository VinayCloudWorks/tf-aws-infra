# Public Route Tables with a default route to the IGW
resource "aws_route_table" "public" {
  for_each = aws_vpc.main

  vpc_id = each.value.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[each.key].id
  }

  tags = {
    Name = "${each.value.tags["Name"]}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.value.tags["vpc_key"]].id
}

# Private Route Tables (without a default route to an IGW)
resource "aws_route_table" "private" {
  for_each = aws_vpc.main

  vpc_id = each.value.id

  tags = {
    Name = "${each.value.tags["Name"]}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.value.tags["vpc_key"]].id
}
