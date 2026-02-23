#!/usr/bin/env bash
# ============================================================================
# provision.sh — Initialize and apply Terraform infrastructure
# ============================================================================
# Usage: ./scripts/provision.sh [plan|apply|output]
#   plan    — run terraform plan only (default)
#   apply   — run terraform apply
#   output  — show terraform outputs
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"
ACTION="${1:-plan}"

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
if ! command -v terraform &>/dev/null; then
  echo "ERROR: 'terraform' is required but not installed."
  exit 1
fi

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
cd "$TERRAFORM_DIR"

echo "============================================"
echo "  Terraform: ${ACTION}"
echo "  Directory: ${TERRAFORM_DIR}"
echo "============================================"

# Initialize (safe to run multiple times)
echo "→ Running terraform init..."
terraform init -upgrade

case "$ACTION" in
  plan)
    echo "→ Running terraform plan..."
    terraform plan -out=tfplan
    echo ""
    echo "To apply: ./scripts/provision.sh apply"
    ;;
  apply)
    if [[ -f tfplan ]]; then
      echo "→ Applying saved plan..."
      terraform apply tfplan
      rm -f tfplan
    else
      echo "→ Running terraform apply..."
      terraform apply
    fi
    echo ""
    echo "============================================"
    echo "  Infrastructure provisioned!"
    echo "============================================"
    terraform output
    ;;
  output)
    terraform output
    ;;
  *)
    echo "Usage: $0 [plan|apply|output]"
    exit 1
    ;;
esac
