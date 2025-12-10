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

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
  default     = []
}

variable "eks_sg_id" {
  description = "EKS security group ID"
  type        = string
  default     = ""
}

variable "eks_cluster_role_arn" {
  description = "EKS cluster role ARN"
  type        = string
  default     = ""
}
