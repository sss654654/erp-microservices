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

variable "mysql_username" {
  description = "MySQL master username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "mysql_password" {
  description = "MySQL master password"
  type        = string
  default     = "erp1234!"
  sensitive   = true
}
