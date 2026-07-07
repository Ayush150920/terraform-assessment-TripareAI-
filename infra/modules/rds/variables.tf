variable "name" {
  description = "Name prefix for all RDS resources (e.g. devops-assessment-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create the RDS instance."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the DB subnet group."
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID of the ECS tasks allowed to reach the database."
  type        = string
}

variable "engine" {
  description = "RDS engine (e.g. postgres)."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "RDS engine version."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t3.micro)."
  type        = string
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling upper bound in GiB."
  type        = number
  default     = 100
}

variable "storage_encrypted" {
  description = "Whether to encrypt storage at rest."
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Initial database name."
  type        = string
}

variable "username" {
  description = "Master username."
  type        = string
}

variable "db_port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "multi_az" {
  description = "Whether to deploy a standby in a second AZ."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups."
  type        = number
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on destroy."
  type        = bool
}

variable "tags" {
  description = "Tags applied to all RDS resources."
  type        = map(string)
  default     = {}
}
