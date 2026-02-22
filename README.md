# PHP Application on AWS ECS Fargate
PHP application deployed on AWS ECS Fargate with ALB, provisioned via Terraform, and automated with GitHub Actions CI/CD.



## Project Structure

```
docker_php_ecs_cicd/
├── .github/workflows/
│   ├── ci.yml                  # PR: lint Dockerfile + build + scan
│   └── cd.yml                  # Push to main: build → ECR → ECS → verify
├── .gitignore
├── app/
│   ├── .dockerignore
│   ├── Dockerfile              # Multi-stage: Composer → PHP 8.3 Apache
│   ├── composer.json           # Slim 4 framework dependencies
│   └── public/
│       └── index.php           # Application entry (/health, /)
├── terraform/
│   ├── backend.tf              # S3 remote state
│   ├── data.tf                 # Data sources (default VPC, subnets, account)
│   ├── iam.tf                  # ECS roles + GitHub Actions OIDC
│   ├── locals.tf               # Computed values
│   ├── main.tf                 # SG, ECR, CloudWatch, ALB, ECS (uses default VPC)
│   ├── outputs.tf              # ALB URL, ECR URL, cluster/service names
│   ├── providers.tf            # AWS provider with assume_role
│   ├── terraform.tfvars        # Variable values
│   ├── variables.tf            # Input variables
│   └── versions.tf             # Provider versions
├── scripts/
│   ├── build-and-push.sh       # Build Docker image and push to ECR
│   ├── provision.sh            # Terraform init/plan/apply
│   └── destroy.sh              # Tear down all resources
└── README.md
```

## Prerequisites

- **AWS CLI** v2 configured with appropriate credentials
- **Terraform** >= 1.5
- **Docker** (for local builds)
- AWS IAM role with permissions to create ECS, ALB, ECR, IAM, CloudWatch resources

## Quick Start

### 1. Provision Infrastructure

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Review the plan
./scripts/provision.sh plan

# Apply infrastructure
./scripts/provision.sh apply
```

### 2. Build and Push Docker Image

```bash
# Auto-detects ECR URL from Terraform output
./scripts/build-and-push.sh

# Or specify a tag
./scripts/build-and-push.sh v1.0.0
```

### 3. Access the Application

```bash
# Get the public URL
cd terraform && terraform output app_url

# Test health endpoint
curl http://<ALB_DNS_NAME>/health
```

## Public Endpoint

After deployment, the application is accessible at:

```
http://<ALB_DNS_NAME>/health
```

Get the URL:
```bash
cd terraform && terraform output -raw app_url
```

### Endpoints

| Method | Path      | Description                      | Response |
|--------|-----------|----------------------------------|----------|
| GET    | `/`       | Root — confirms app is running   | 200 JSON |
| GET    | `/health` | Health check for ALB / ECS       | 200 JSON |

### Health Response Example

```json
{
  "status": "healthy",
  "timestamp": "2026-02-22T12:00:00Z",
  "service": "php-app",
  "version": "1.0.0"
}
```

## CI/CD Pipeline

### CI — Pull Requests (`ci.yml`)

```
PR to main (app/ changes)
  └─► Lint Dockerfile (hadolint)
       └─► Build image (no push)
            └─► [Trivy scan — disabled]
```

### CD — Deployment (`cd.yml`)

```
Push to main (app/ changes)
  └─► Build & push to ECR (sha-<commit> tag)
       └─► Update ECS task definition with new image
            └─► Deploy to ECS (wait for stability)
                 └─► Health check (GET /health → 200)
```

### GitHub Repository Setup

Set these in your repository:

**Secrets:**
- `AWS_REGION` — e.g., `eu-central-1`
- `ECR_AWS_ROLE_ARN` — from `terraform output github_actions_role_arn`

**Variables:**
- `APP_URL` — from `terraform output app_url`

## Infrastructure Details

### AWS Resources Provisioned

| Resource | Description |
|----------|-------------|
| Security Groups | ALB SG (HTTP:80 inbound) + ECS SG (8080 from ALB only) |
| ECR Repository | `php-app` with immutable tags and lifecycle policies |
| ECS Cluster | Fargate cluster with Container Insights |
| ECS Task Definition | 0.25 vCPU, 512 MB, PHP 8.3 Apache container |
| ECS Service | Fargate with circuit breaker and zero-downtime deploys |
| ALB | Internet-facing with health check on `/health` |
| CloudWatch Log Group | `/ecs/allflex-prod-php-app`, 7-day retention |
| IAM Roles | ECS execution role, task role, GitHub Actions OIDC role |

### Estimated Costs (Minimal Config)

| Resource | Approximate Monthly Cost |
|----------|--------------------------|
| Fargate (0.25 vCPU, 512 MB × 1 task) | ~$9 |
| ALB | ~$16 + data processing |
| CloudWatch Logs | ~$0.50/GB |
| ECR | ~$0.10/GB stored |
| **Total** | **~$26/month** |

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/build-and-push.sh [TAG]` | Build Docker image and push to ECR |
| `scripts/provision.sh [plan\|apply\|output]` | Terraform init, plan, or apply |
| `scripts/destroy.sh [--force]` | Destroy all AWS resources |

## Cleanup

```bash
# Interactive (asks for confirmation)
./scripts/destroy.sh

# Non-interactive
./scripts/destroy.sh --force
```

## Trade-offs and Decisions

| Decision | Rationale |
|----------|-----------|
| **Public subnets for Fargate** | Uses default VPC public subnets with `assign_public_ip`. Avoids NAT Gateway cost (~$32/month). In production, use private subnets + NAT for network isolation. |
| **HTTP only (no HTTPS)** | No domain or ACM certificate required for demo. In production, add HTTPS listener with ACM. |
| **Single Fargate task** | Minimal cost. Scale `desired_count` and enable autoscaling for production HA. |
| **ECS circuit breaker** | Native AWS rollback on failed deployments — more reliable than application-level rollback. |
| **OIDC federation** | No long-lived AWS credentials in GitHub. Follows AWS security best practices. |
| **assume_role provider** | Enterprise-standard pattern for cross-account or delegated Terraform access. |
| **Default VPC** | Simplifies networking for a test task. In production, use a dedicated VPC with proper subnet tiers. |
| **Immutable ECR tags** | Prevents tag overwrite attacks. Enforces unique image identification. |

## Assumptions

1. AWS account with permissions to create all required resources
2. S3 bucket `sharedlabs-tfstate` exists for Terraform remote state
3. IAM role for `assume_role` (`TerraformBootstrap`) exists
4. GitHub OIDC provider is configured once per AWS account (Terraform manages this)
5. DNS/HTTPS not required — application accessed via ALB DNS name
6. Single environment (`prod`) — extend with workspaces or separate configs for multi-env
