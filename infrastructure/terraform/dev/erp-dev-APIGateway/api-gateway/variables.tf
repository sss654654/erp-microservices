variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for VPC Link"
  type        = list(string)
}

variable "nlb_listener_arns" {
  description = "NLB listener ARNs"
  type        = map(string)
}

variable "nlb_dns_name" {
  description = "NLB DNS name"
  type        = string
}
