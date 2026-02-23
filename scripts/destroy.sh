#!/usr/bin/env bash
# ============================================================================
# destroy.sh — Destroy all provisioned infrastructure
# ============================================================================
# Usage: ./scripts/destroy.sh [--force]
#   --force  — skip confirmation prompt
# Required environment variables:
#   AWS_REGION
#   ECR_REPO
# ============================================================================

set -xeuo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"
FORCE="${1:-}"

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
for cmd in terraform aws; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not installed."
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Confirmation
# ---------------------------------------------------------------------------
if [[ "$FORCE" != "--force" ]]; then
  echo "============================================"
  echo "  WARNING: This will destroy ALL resources!"
  echo "============================================"
  read -rp "Are you sure? Type 'yes' to confirm: " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Clean ECR images (required before destroying ECR repo if force_delete = false)
# ---------------------------------------------------------------------------
cd "$TERRAFORM_DIR"
terraform init -upgrade >/dev/null 2>&1


if [[ -n "$ECR_REPO" ]]; then
  REPO_NAME="${ECR_REPO##*/}"
  echo "→ Cleaning ECR images in repository: ${REPO_NAME}..."
  IMAGE_IDS=$(aws ecr list-images --repository-name "$REPO_NAME" --region "$AWS_REGION" --query 'imageIds[*]' --output json 2>/dev/null || echo "[]")
  if [[ "$IMAGE_IDS" != "[]" && "$IMAGE_IDS" != "" ]]; then
    echo "$IMAGE_IDS" | aws ecr batch-delete-image --repository-name "$REPO_NAME" --region "$AWS_REGION" --image-ids file:///dev/stdin >/dev/null 2>&1 || true
    echo "  ECR images cleaned."
  else
    echo "  No images to clean."
  fi
fi

# ---------------------------------------------------------------------------
# Destroy infrastructure
# ---------------------------------------------------------------------------
echo ""
echo "→ Running terraform destroy..."
terraform destroy -auto-approve

echo ""
echo "============================================"
echo "  All resources destroyed."
echo "============================================"
