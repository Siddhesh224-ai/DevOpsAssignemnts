variable "aws_region" {
  description = "AWS region for the TaskBoard VPC and EKS cluster."
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "taskboard-eks"
}

variable "environment" {
  description = "Environment tag applied to infrastructure."
  type        = string
  default     = "dev"
}
