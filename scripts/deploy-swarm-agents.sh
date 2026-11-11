#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
AWS_PROFILE=${AWS_PROFILE:-duoc}
AWS_REGION=${AWS_REGION:-us-east-1}

MANAGER_ID=$(terraform -chdir="$ROOT_DIR" output -raw swarm_manager_instance_id)
LOKI_HOST=$(terraform -chdir="$ROOT_DIR" output -raw observability_private_ip)
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

cp "$ROOT_DIR/monitoring/agents-stack.yml" "$WORK_DIR/agents-stack.yml"
cp "$ROOT_DIR/monitoring/alloy.alloy" "$WORK_DIR/alloy.alloy"
STACK_B64=$(base64 < "$WORK_DIR/agents-stack.yml" | tr -d '\n')
ALLOY_B64=$(base64 < "$WORK_DIR/alloy.alloy" | tr -d '\n')

REMOTE_COMMAND="set -eu
mkdir -p /opt/swarm-observability
printf '%s' '$STACK_B64' | base64 -d > /opt/swarm-observability/agents-stack.yml
printf '%s' '$ALLOY_B64' | base64 -d > /opt/swarm-observability/alloy.alloy
cd /opt/swarm-observability
LOKI_HOST='$LOKI_HOST' docker stack deploy --with-registry-auth -c agents-stack.yml swarm-observability
docker stack services swarm-observability"
PARAMETERS=$(jq -cn --arg command "$REMOTE_COMMAND" '{commands:[$command]}')

COMMAND_ID=$(aws ssm send-command \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --document-name AWS-RunShellScript \
  --comment "Deploy Swarm metrics and log agents" \
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
