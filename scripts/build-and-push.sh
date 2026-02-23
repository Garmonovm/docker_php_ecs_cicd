#!/usr/bin/env bash
# ============================================================================
# build-and-push.sh — Build Docker image and push to Amazon ECR
# ============================================================================
# Usage: ./scripts/build-and-push.sh [IMAGE_TAG]
#   IMAGE_TAG  — optional; defaults to sha-<short-git-hash>
#
# Required environment variables:
#   AWS_REGION
#   ECR_REPOSITORY_URL
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="${PROJECT_ROOT}/app"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

IMAGE_TAG="${1:-sha-$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)}"

# Auto-detect from Terraform outputs if not set
if [[ -z "${AWS_REGION:-}" ]]; then
  AWS_REGION=$(cd "$TERRAFORM_DIR" && terraform output -raw 2>/dev/null | grep -q . && terraform output -raw aws_region 2>/dev/null || echo "eu-central-1")
  echo "Using AWS_REGION=${AWS_REGION} (from default)"
fi

if [[ -z "${ECR_REPOSITORY_URL:-}" ]]; then
  ECR_REPOSITORY_URL=$(cd "$TERRAFORM_DIR" && terraform output -raw ecr_repository_url 2>/dev/null || true)
  if [[ -z "$ECR_REPOSITORY_URL" ]]; then
    echo "ERROR: ECR_REPOSITORY_URL not set and could not read from terraform output."
    echo "Usage: ECR_REPOSITORY_URL=<url> AWS_REGION=<region> $0 [IMAGE_TAG]"
    exit 1
  fi
fi

# Extract registry URL for docker login
ECR_REGISTRY="${ECR_REPOSITORY_URL%%/*}"

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
for cmd in aws docker; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not installed."
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Build & Push
# ---------------------------------------------------------------------------
echo "============================================"
echo "  Building: ${ECR_REPOSITORY_URL}:${IMAGE_TAG}"
echo "============================================"

# Authenticate Docker to ECR
echo "→ Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Build the image
echo "→ Building Docker image..."
docker build -t "${ECR_REPOSITORY_URL}:${IMAGE_TAG}" "$APP_DIR"

# Push to ECR
echo "→ Pushing to ECR..."
docker push "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"

echo "============================================"
echo "  Successfully pushed: ${ECR_REPOSITORY_URL}:${IMAGE_TAG}"
echo "============================================"
