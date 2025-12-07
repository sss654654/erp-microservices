data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "security_groups" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/security-groups/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.terraform_remote_state.security_groups.outputs.alb_sg_id]
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "employee" {
  name     = "${var.project_name}-${var.environment}-employee-tg"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/employees"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200,404"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-employee-tg"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "approval_request" {
  name     = "${var.project_name}-${var.environment}-approval-req-tg"
  port     = 8082
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/approvals"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200,404"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-approval-req-tg"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "approval_processing" {
  name     = "${var.project_name}-${var.environment}-approval-proc-tg"
  port     = 8083
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/process/1"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200,404"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-approval-proc-tg"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "notification" {
  name     = "${var.project_name}-${var.environment}-notification-tg"
  port     = 8084
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/notifications/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200,404"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-notification-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "employee" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.employee.arn
  }

  condition {
    path_pattern {
      values = ["/employees*", "/api/employees/*"]
    }
  }
}

resource "aws_lb_listener_rule" "approval_request" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.approval_request.arn
  }

  condition {
    path_pattern {
      values = ["/approvals*", "/api/approvals/*"]
    }
  }
}

resource "aws_lb_listener_rule" "approval_processing" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.approval_processing.arn
  }

  condition {
    path_pattern {
      values = ["/process*", "/api/processing/*"]
    }
  }
}

resource "aws_lb_listener_rule" "notification" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 400

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.notification.arn
  }

  condition {
    path_pattern {
      values = ["/notifications*", "/api/notifications/*"]
    }
  }
}
