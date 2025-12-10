data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = data.terraform_remote_state.vpc.outputs.vpc_id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                            = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Environment                                     = var.environment
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = data.terraform_remote_state.vpc.outputs.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                            = "${var.project_name}-${var.environment}-private-${count.index + 1}"
    Environment                                     = var.environment
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

resource "aws_subnet" "data" {
  count             = length(var.availability_zones)
  vpc_id            = data.terraform_remote_state.vpc.outputs.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat"
    Environment = var.environment
  }
}
