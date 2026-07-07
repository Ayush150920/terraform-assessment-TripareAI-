variable "project" {
  description = "Project name, used in the resource name prefix."
  type        = string
  default     = "devops-assessment"
}

variable "environment" {
  description = "Environment name (dev/prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

# --- Network ---
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (one per AZ)."
  type        = list(string)
}

# --- ECS / app ---
variable "container_image" {
  description = "Container image for the placeholder app."
  type        = string
}

variable "container_port" {
  description = "Container listen port."
  type        = number
}

variable "desired_count" {
  description = "Number of Fargate task replicas."
  type        = number
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = string
}

variable "task_memory" {
  description = "Fargate task memory (MiB)."
  type        = string
}

# --- RDS ---
variable "db_engine" {
  description = "RDS engine."
  type        = string
}

variable "db_engine_version" {
  description = "RDS engine version."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_allocated_storage" {
  description = "RDS initial storage (GiB)."
  type        = number
}

variable "db_max_allocated_storage" {
  description = "RDS storage autoscaling limit (GiB)."
  type        = number
}

variable "db_name" {
  description = "Initial database name."
  type        = string
}

variable "db_username" {
  description = "RDS master username."
  type        = string
}

variable "db_multi_az" {
  description = "Whether RDS runs multi-AZ."
  type        = bool
}

variable "db_backup_retention_period" {
  description = "RDS automated backup retention (days)."
  type        = number
}

variable "db_deletion_protection" {
  description = "Whether RDS deletion protection is enabled."
  type        = bool
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the RDS final snapshot on destroy."
  type        = bool
}
