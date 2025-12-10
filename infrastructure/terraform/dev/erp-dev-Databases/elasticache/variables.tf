variable "project_name" {
  description = "Project name"
  type        = string
  default     = "erp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "redis_version" {
  description = "Redis version"
  type        = string
  default     = "7.0"
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}
