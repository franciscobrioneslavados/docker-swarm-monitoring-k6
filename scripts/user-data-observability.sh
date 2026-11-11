#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl docker.io docker-compose-v2 openssl unzip
systemctl enable --now docker

AWS_CLI_INSTALL_DIR=$(mktemp -d)
trap 'rm -rf "$AWS_CLI_INSTALL_DIR"' EXIT
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
  -o "$AWS_CLI_INSTALL_DIR/awscliv2.zip"
unzip -q "$AWS_CLI_INSTALL_DIR/awscliv2.zip" -d "$AWS_CLI_INSTALL_DIR"
"$AWS_CLI_INSTALL_DIR/aws/install" --update

install -d -m 0755 /opt/observability/secrets
install -d -m 0755 /opt/observability/certs
install -d -m 0755 /opt/observability/grafana/provisioning/datasources
install -d -m 0755 /opt/observability/grafana/provisioning/dashboards
install -d -m 0755 /opt/observability/grafana/dashboards
install -d -m 0755 /opt/observability/targets

printf '%s' '${compose_b64}' | base64 -d > /opt/observability/docker-compose.yml
printf '%s' '${prometheus_b64}' | base64 -d > /opt/observability/prometheus.yml
printf '%s' '${loki_b64}' | base64 -d > /opt/observability/loki.yml
printf '%s' '${targets_refresh_b64}' | base64 -d > /usr/local/sbin/refresh-prom-targets
chmod 0755 /usr/local/sbin/refresh-prom-targets
printf '%s' '${datasources_b64}' | base64 -d > /opt/observability/grafana/provisioning/datasources/datasources.yml
printf '%s' '${dashboards_provisioning_b64}' | base64 -d > /opt/observability/grafana/provisioning/dashboards/dashboards.yml
printf '%s' '${dashboard_b64}' | base64 -d > /opt/observability/grafana/dashboards/swarm-overview.json

PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
printf '%s\n' "$PASSWORD" > /opt/observability/secrets/grafana_admin_password
chown 472:472 /opt/observability/secrets/grafana_admin_password
chmod 0400 /opt/observability/secrets/grafana_admin_password
printf 'username=admin\npassword=%s\n' "$PASSWORD" > /root/grafana-admin-credentials
chmod 0600 /root/grafana-admin-credentials
unset PASSWORD

IMDS_TOKEN=$(curl -fsS -X PUT \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' \
  http://169.254.169.254/latest/api/token)
PUBLIC_IP=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)
openssl req -x509 -nodes -newkey rsa:3072 -days 365 \
  -keyout /opt/observability/certs/grafana.key \
  -out /opt/observability/certs/grafana.crt \
  -subj '/CN=grafana-observability' \
  -addext "subjectAltName=IP:$PUBLIC_IP"
chown 472:472 /opt/observability/certs/grafana.key
chmod 0400 /opt/observability/certs/grafana.key
chmod 0644 /opt/observability/certs/grafana.crt

cat > /etc/systemd/system/observability-target-discovery.service <<EOF
[Unit]
Description=Refresh Prometheus targets from EC2 instance tags
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/refresh-prom-targets ${aws_region} ${project_name}
EOF

cat > /etc/systemd/system/observability-target-discovery.timer <<'EOF'
[Unit]
Description=Refresh Prometheus EC2 targets every minute

[Timer]
OnBootSec=15s
OnUnitActiveSec=60s
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now observability-target-discovery.timer
/usr/local/sbin/refresh-prom-targets '${aws_region}' '${project_name}'

cd /opt/observability
docker compose pull
docker compose up -d
docker compose ps
