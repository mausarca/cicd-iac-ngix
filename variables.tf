variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}


variable "role_arn" {
  type = string
}


variable "name" {
  description = "Prefix for all resources"
  default     = "cicd-iac-test"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
