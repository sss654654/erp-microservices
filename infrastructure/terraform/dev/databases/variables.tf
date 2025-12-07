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

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "mysql_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "mysql_database_name" {
  description = "MySQL database name"
  type        = string
  default     = "erp"
}

variable "mysql_username" {
  description = "MySQL master username"
  type        = string
  default     = "admin"
}

variable "mysql_password" {
  description = "MySQL master password"
  type        = string
  sensitive   = true
}

variable "redis_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}
