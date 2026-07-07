variable "name" {
  description = "Name prefix for all ECS resources (e.g. devops-assessment-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create the ALB and ECS resources."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the internet-facing ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets in which Fargate tasks run."
  type        = list(string)
}

variable "container_image" {
  description = "Container image for the app task (e.g. nginx:1.27-alpine)."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 80
}

variable "desired_count" {
  description = "Number of task replicas."
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Fargate task CPU units (e.g. 256, 512, 1024)."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory in MiB (e.g. 512, 1024, 2048)."
  type        = string
  default     = "512"
}

variable "health_check_path" {
  description = "ALB target group health check path."
  type        = string
  default     = "/"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 14
}

variable "aws_region" {
  description = "Region used for the awslogs log driver configuration."
  type        = string
}

variable "tags" {
  description = "Tags applied to all ECS resources."
  type        = map(string)
  default     = {}
}
