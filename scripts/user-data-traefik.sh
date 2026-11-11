#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1

PROJECT="${project_name}"
AWS_REGION="${aws_region}"
BACKEND_PORT="${backend_port}"

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

ATTEMPTS=0
until [ "$ATTEMPTS" -ge 180 ]; do
  MANAGER_IP=$(aws ec2 describe-instances \
    --filters \
      "Name=tag:Project,Values=$PROJECT" \
      "Name=tag:Role,Values=Manager" \
      "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || true)

  if [ -n "$MANAGER_IP" ] && [ "$MANAGER_IP" != "None" ]; then
    break
  fi

  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 10
done

if [ -z "$MANAGER_IP" ] || [ "$MANAGER_IP" = "None" ]; then
  echo "Timed out waiting for the Swarm manager." >&2
  exit 1
fi

mkdir -p /etc/traefik
cat > /etc/traefik/traefik.yml <<'EOF'
entryPoints:
  web:
    address: ":80"
providers:
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true
EOF

cat > /etc/traefik/dynamic.yml <<EOF
http:
  routers:
    swarm-app:
      rule: "PathPrefix(\`/\`)"
      entryPoints:
        - web
      service: swarm-app
  services:
    swarm-app:
      loadBalancer:
        servers:
          - url: "http://$MANAGER_IP:$BACKEND_PORT"
EOF

docker rm -f traefik >/dev/null 2>&1 || true
docker run \
  --detach \
  --name traefik \
  --restart unless-stopped \
  --publish 80:80 \
  --volume /etc/traefik/traefik.yml:/etc/traefik/traefik.yml:ro \
  --volume /etc/traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro \
  traefik:v3
