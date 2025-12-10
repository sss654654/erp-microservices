data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "subnet" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/subnet/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_route_table" "public" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.terraform_remote_state.vpc.outputs.igw_id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = data.terraform_remote_state.subnet.outputs.nat_gateway_id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(data.terraform_remote_state.subnet.outputs.public_subnet_ids)
  subnet_id      = data.terraform_remote_state.subnet.outputs.public_subnet_ids[count.index]
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(data.terraform_remote_state.subnet.outputs.private_subnet_ids)
  subnet_id      = data.terraform_remote_state.subnet.outputs.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private.id
}
