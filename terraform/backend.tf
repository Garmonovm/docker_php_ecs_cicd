terraform {
  backend "s3" {
    bucket       = "sharedlabs-tfstate"
    key          = "lab-docker-php-ecs-cicd/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}
