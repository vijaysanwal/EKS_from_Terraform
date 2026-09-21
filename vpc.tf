data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "eks" {
  cidr_block       = var.cidr
  instance_tenancy = "default"

  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.eks.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.cidr, 8, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name                                      = "eks-public-subnet-${count.index + 1}"
    "kubernetes.io/role/elb"                  = "1"
    "kubernetes.io/cluster/test-eks-cluster" = "shared"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.eks.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(var.cidr, 8, count.index + 2)

  tags = {
    Name                                      = "eks-private-subnet-${count.index + 1}"
    "kubernetes.io/role/internal-elb"         = "1"
    "kubernetes.io/cluster/test-eks-cluster" = "shared"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = "eks-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "eks-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "eks" {
  name        = "eks-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.eks.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-sg"
  }
}

resource "aws_s3_bucket" "eks" {
  bucket = "eks-vijay-test-bucket"

  tags = {
    Name = "eks-bucket"
  }
}

resource "aws_eip" "nat" {
  count = 2

  domain = "vpc"

  tags = {
    Name = "eks-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [
    aws_internet_gateway.main
  ]

  tags = {
    Name = "eks-nat-${count.index + 1}"
  }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "eks-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
