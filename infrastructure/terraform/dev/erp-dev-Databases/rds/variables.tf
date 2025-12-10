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

variable "mysql_version" {
  description = "MySQL version"
  type        = string
  default     = "8.0.40"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage"
  type        = number
  default     = 20
}

variable "mysql_database_name" {
  description = "MySQL database name"
  type        = string
  default     = "erp"
}

variable "mysql_username" {
  description = "MySQL username"
  type        = string
  default     = "admin"
}

variable "mysql_password" {
  description = "MySQL password"
  type        = string
  sensitive   = true
}
