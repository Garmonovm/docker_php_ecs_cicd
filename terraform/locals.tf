locals {
  account_id   = data.aws_caller_identity.current.account_id
  ecr_registry = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  name_prefix  = "${var.project_name}-${var.environment}"
  app_name     = "php-app"
}
