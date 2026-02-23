variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "allflex"
}

variable "assume_role_arn" {
  description = "IAM role ARN to assume for AWS provider"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "container_cpu" {
  description = "CPU units for the Fargate task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Memory (MiB) for the Fargate task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "app_image_tag" {
  description = "Docker image tag to deploy (overridden by CI/CD)"
  type        = string
  default     = "latest"
}

variable "image_retention_count" {
  description = "Number of release images (v* tags) to keep in ECR"
  type        = number
  default     = 10
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}
