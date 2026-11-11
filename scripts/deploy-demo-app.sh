#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
AWS_PROFILE=${AWS_PROFILE:-duoc}
AWS_REGION=${AWS_REGION:-us-east-1}
IMAGE_TAG=${1:-$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}

REPOSITORY=$(terraform -chdir="$ROOT_DIR" output -raw app_repository_url)
MANAGER_ID=$(terraform -chdir="$ROOT_DIR" output -raw swarm_manager_instance_id)
REGISTRY=${REPOSITORY%%/*}
IMAGE="$REPOSITORY:$IMAGE_TAG"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

tar -czf "$WORK_DIR/demo-app.tar.gz" -C "$ROOT_DIR/app" .
APP_B64=$(base64 < "$WORK_DIR/demo-app.tar.gz" | tr -d '\n')
sed "s|__APP_IMAGE__|$IMAGE|g" "$ROOT_DIR/app/stack.yml" > "$WORK_DIR/app-stack.yml"
STACK_B64=$(base64 < "$WORK_DIR/app-stack.yml" | tr -d '\n')
REMOTE_COMMAND="set -eu
cleanup() {
  if ! docker logout '$REGISTRY'; then
    echo 'Warning: Docker logout failed for $REGISTRY' >&2
  fi
}
trap cleanup EXIT
mkdir -p /tmp/docker-swarm-demo-app
printf '%s' '$APP_B64' | base64 -d | tar -xz -C /tmp/docker-swarm-demo-app
docker build --platform linux/amd64 -t '$IMAGE' /tmp/docker-swarm-demo-app
aws ecr get-login-password --region '$AWS_REGION' | docker login --username AWS --password-stdin '$REGISTRY'
docker push '$IMAGE'
printf '%s' '$STACK_B64' | base64 -d > /tmp/demo-app-stack.yml
docker stack deploy --with-registry-auth -c /tmp/demo-app-stack.yml demo
docker stack services demo"
PARAMETERS=$(jq -cn --arg command "$REMOTE_COMMAND" '{commands:[$command]}')

COMMAND_ID=$(aws ssm send-command \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --document-name AWS-RunShellScript \
  --comment "Deploy demo app image $IMAGE_TAG" \
  --instance-ids "$MANAGER_ID" \
  --parameters "$PARAMETERS" \
  --query 'Command.CommandId' \
  --output text)

aws ssm wait command-executed \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --command-id "$COMMAND_ID" \
  --instance-id "$MANAGER_ID"

aws ssm get-command-invocation \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --command-id "$COMMAND_ID" \
  --instance-id "$MANAGER_ID" \
  --query '{Status:Status,Output:StandardOutputContent,Error:StandardErrorContent}' \
  --output json
