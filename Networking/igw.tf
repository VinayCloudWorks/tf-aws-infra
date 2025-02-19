resource "aws_internet_gateway" "this" {
  for_each = aws_vpc.main

  vpc_id = each.value.id

  tags = {
    Name = "${each.value.tags["Name"]}-igw"
  }
}
