variable "name" {
  description = "Name prefix for all network resources (e.g. devops-assessment-dev)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones. Length must match the subnet CIDR lists."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public (ALB) subnets, one per AZ."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private (ECS/RDS) subnets, one per AZ."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to all network resources."
  type        = map(string)
  default     = {}
}
