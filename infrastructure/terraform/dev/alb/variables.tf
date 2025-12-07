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
