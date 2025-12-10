resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-${var.environment}-node-"
  instance_type = var.node_instance_types[0]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}-node"
      Environment = var.environment
    }
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.project_name}-${var.environment}-node-group"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  capacity_type = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-node-group"
    Environment = var.environment
  }
}
