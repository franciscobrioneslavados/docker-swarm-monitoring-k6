#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1

NODE_ROLE="${node_role}"
PROJECT="${project_name}"
AWS_REGION="${aws_region}"
TOKEN_PARAMETER="${token_parameter}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl docker.io unzip

AWS_CLI_INSTALL_DIR=$(mktemp -d)
trap 'rm -rf "$AWS_CLI_INSTALL_DIR"' EXIT
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
  -o "$AWS_CLI_INSTALL_DIR/awscliv2.zip"
unzip -q "$AWS_CLI_INSTALL_DIR/awscliv2.zip" -d "$AWS_CLI_INSTALL_DIR"
"$AWS_CLI_INSTALL_DIR/aws/install" --update

systemctl enable --now docker

if [ "$NODE_ROLE" = "manager" ]; then
  SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}')
  if [ "$SWARM_STATE" = "inactive" ]; then
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    docker swarm init --advertise-addr "$LOCAL_IP"
  fi

  TOKEN=$(docker swarm join-token worker -q)
  aws ssm put-parameter \
    --name "$TOKEN_PARAMETER" \
    --value "$TOKEN" \
    --type SecureString \
    --overwrite \
    --region "$AWS_REGION"
else
  SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}')
  if [ "$SWARM_STATE" != "inactive" ]; then
    echo "Docker is already part of a Swarm: $SWARM_STATE"
    exit 0
  fi

  ATTEMPTS=0
  until [ "$ATTEMPTS" -ge 180 ]; do
    TOKEN=$(aws ssm get-parameter \
      --name "$TOKEN_PARAMETER" \
      --with-decryption \
      --query 'Parameter.Value' \
      --output text \
      --region "$AWS_REGION" 2>/dev/null || true)

    MANAGER_IP=$(aws ec2 describe-instances \
      --filters \
        "Name=tag:Project,Values=$PROJECT" \
        "Name=tag:Role,Values=Manager" \
        "Name=instance-state-name,Values=running" \
      --query 'Reservations[0].Instances[0].PrivateIpAddress' \
      --output text \
      --region "$AWS_REGION" 2>/dev/null || true)

    if [ -n "$TOKEN" ] && [ "$TOKEN" != "None" ] && \
       [ -n "$MANAGER_IP" ] && [ "$MANAGER_IP" != "None" ]; then
      docker swarm join --token "$TOKEN" "$MANAGER_IP:2377"
      exit 0
    fi

    ATTEMPTS=$((ATTEMPTS + 1))
    sleep 10
  done

  echo "Timed out waiting for the Swarm manager and worker token." >&2
  exit 1
fi
