# NLB 생성 (VPC Link용)
resource "aws_lb" "nlb" {
  name               = "${var.project_name}-${var.environment}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-nlb"
    Environment = var.environment
  }
}

# NLB Target Groups (4개 서비스)
resource "aws_lb_target_group" "employee" {
  name        = "${var.project_name}-${var.environment}-employee-nlb-tg"
  port        = 8081
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-employee-nlb-tg"
  }
}

resource "aws_lb_target_group" "approval_request" {
  name        = "${var.project_name}-${var.environment}-approval-req-nlb-tg"
  port        = 8082
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-approval-req-nlb-tg"
  }
}

resource "aws_lb_target_group" "approval_processing" {
  name        = "${var.project_name}-${var.environment}-approval-proc-nlb-tg"
  port        = 8083
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-approval-proc-nlb-tg"
  }
}

resource "aws_lb_target_group" "notification" {
  name        = "${var.project_name}-${var.environment}-notification-nlb-tg"
  port        = 8084
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-notification-nlb-tg"
  }
}

# NLB Listeners
resource "aws_lb_listener" "employee" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8081
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.employee.arn
  }
}

resource "aws_lb_listener" "approval_request" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8082
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.approval_request.arn
  }
}

resource "aws_lb_listener" "approval_processing" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8083
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.approval_processing.arn
  }
}

resource "aws_lb_listener" "notification" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8084
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.notification.arn
  }
}
