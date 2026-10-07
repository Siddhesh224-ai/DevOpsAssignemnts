variable "aws_region" {
  description = "AWS region for the Session 19 mini project."
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance size for the demo web server."
  type        = string
  default     = "t4g.micro"
}

variable "bucket_prefix" {
  description = "Globally unique S3 bucket prefix; AWS adds a generated suffix."
  type        = string
  default     = "siddhesh-session19-artifacts-"
}
