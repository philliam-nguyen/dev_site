resource "aws_vpc" "this" {
  # The CIDR block is arbitrary, but should avoid
  # conflicts with tailnet.
  cidr_block = "10.20.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "meal-prep" }
}

# use1-az3 is excluded from CloudFront VPC origins, and AZ *names* are
# shuffled per account, so the zone is pinned by its account-independent ID.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.0.0/24"
  availability_zone_id    = "use1-az6"
  map_public_ip_on_launch = true

  tags = { Name = "meal-prep-public" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "meal-prep" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "meal-prep-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
