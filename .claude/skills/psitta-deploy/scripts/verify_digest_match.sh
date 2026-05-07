#!/usr/bin/env bash
# Verify ECR :latest digest matches the running ECS task's containerImageDigest.
# Polls every 30s up to MAX_POLLS for convergence (rolling deploy in progress).
# Usage: verify_digest_match.sh [max_polls=10]
# Exit 0: ECR == ECS digest (all running tasks on the same digest as ECR :latest).
# Exit 1: timeout before convergence.

set -euo pipefail

CLUSTER="psitta-cluster"
SERVICE="psitta-api"
REPO="psitta-api"
PROFILE="psitta-prod"
REGION="us-east-1"
MAX_POLLS="${1:-10}"
INT=30

ECR_DIGEST=$(aws ecr describe-images \
  --profile "$PROFILE" --region "$REGION" \
  --repository-name "$REPO" --image-ids imageTag=latest \
  --query "imageDetails[0].imageDigest" --output text)
ECR_PUSHED=$(aws ecr describe-images \
  --profile "$PROFILE" --region "$REGION" \
  --repository-name "$REPO" --image-ids imageTag=latest \
  --query "imageDetails[0].imagePushedAt" --output text)

echo "ECR :latest digest : $ECR_DIGEST"
echo "ECR pushedAt       : $ECR_PUSHED"

for i in $(seq 1 "$MAX_POLLS"); do
  TASKS=$(aws ecs list-tasks \
    --profile "$PROFILE" --region "$REGION" \
    --cluster "$CLUSTER" --service-name "$SERVICE" \
    --desired-status RUNNING --query 'taskArns' --output text)
  if [[ -z "$TASKS" ]]; then
    echo "[poll $i] no running tasks yet"
    sleep "$INT"; continue
  fi
  ECS_DIGESTS=$(aws ecs describe-tasks \
    --profile "$PROFILE" --region "$REGION" \
    --cluster "$CLUSTER" --tasks $TASKS \
    --query 'tasks[].containers[].imageDigest' --output text)
  COUNT=$(echo "$TASKS" | wc -w)
  UNIQ=$(echo "$ECS_DIGESTS" | tr -s ' \t' '\n' | sort -u | wc -l)
  echo "[poll $i] tasks=$COUNT  uniq_digests=$UNIQ  digests=$ECS_DIGESTS"
  if [[ "$UNIQ" == "1" ]] && echo "$ECS_DIGESTS" | grep -q "${ECR_DIGEST#sha256:}"; then
    echo "*** CONVERGED: all running tasks on ECR :latest digest ***"
    exit 0
  fi
  sleep "$INT"
done

echo "TIMEOUT: ECR != ECS digest after $((MAX_POLLS * INT))s"
exit 1
