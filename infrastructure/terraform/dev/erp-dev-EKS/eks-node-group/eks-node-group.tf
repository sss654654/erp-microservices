resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-${var.environment}-service-node-"
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
      Name        = "${var.project_name}-${var.environment}-service-node"
      Environment = var.environment
    }
  }
}

resource "aws_launch_template" "kafka" {
  name_prefix   = "${var.project_name}-${var.environment}-kafka-node-"
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
      Name        = "${var.project_name}-${var.environment}-kafka-node"
      Environment = var.environment
    }
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.project_name}-${var.environment}-service-node-group"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  capacity_type = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-service-node-group"
    Environment = var.environment
  }
}

resource "aws_eks_node_group" "kafka" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.project_name}-${var.environment}-kafka-node-group"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.kafka.id
    version = "$Latest"
  }

  capacity_type = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  taint {
    key    = "workload"
    value  = "kafka"
    effect = "NO_SCHEDULE"
  }

  labels = {
    workload = "kafka"
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-kafka-node-group"
    Environment = var.environment
  }
}
