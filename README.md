# PHP Application on AWS ECS Fargate with CI/CD

## Overview
This repository contains a PHP application deployed on AWS ECS Fargate with ALB, provisioned via Terraform, and automated with GitHub Actions CI/CD.

## CI/CD Pipeline
- **CI**: On pull requests, runs linting, scanning, and builds the Docker image.
- **CD**: On push to main, builds and pushes the Docker image to ECR, updates the ECS task definition, deploys to ECS, and verifies service stability.

## Required Environment Variables
### For Local Terraform and Scripts
- `AWS_REGION`: AWS region where resources will be provisioned (e.g., `us-east-1`).
- `ECR_REPOSITORY_URL`: URL of the ECR repository (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com/php-app`).

### For GitHub Actions
- `AWS_REGION`: AWS region where resources will be provisioned.
- `ECR_AWS_ROLE_ARN`: IAM role ARN for GitHub Actions to assume.

## Scripts
| Script                        | Description                                      |
|-------------------------------|--------------------------------------------------|
| `scripts/build-and-push.sh`   | Build Docker image and push to ECR.             |
| `scripts/provision.sh`        | Terraform init, plan, or apply infrastructure.  |
| `scripts/destroy.sh`          | Destroy all AWS resources.                      |

### Usage

#### Provision Infrastructure
```bash
chmod +x scripts/*.sh
./scripts/provision.sh plan
./scripts/provision.sh apply
```

#### Build and Push Docker Image
```bash
./scripts/build-and-push.sh
./scripts/build-and-push.sh v1.0.0
```

#### Access Application
```bash
cd terraform && terraform output -raw app_url
curl http://<ALB_DNS_NAME>/health
```

#### Destroy Infrastructure
```bash
./scripts/destroy.sh
./scripts/destroy.sh --force
```
