#!/bin/bash
set -euo pipefail

AWS_REGION=${1:?AWS region is required}
PROJECT=${2:?Project name is required}
TARGET_DIR=${TARGET_DIR:-/opt/observability/targets}
mkdir -p "$TARGET_DIR"

aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:Project,Values=$PROJECT" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{private_ip:PrivateIpAddress,instance_id:InstanceId,tags:Tags}' \
  --output json |
  python3 -c '
import json
import os
import sys
import tempfile

directory = sys.argv[1]
instances = json.load(sys.stdin)
targets = {"nodes.json": [], "containers.json": [], "demo-app.json": []}

for instance in instances:
    tags = {tag["Key"]: tag["Value"] for tag in instance["tags"]}
    role = tags.get("Role")
    address = instance.get("private_ip")
    if not address or role not in ("Manager", "Worker"):
        continue

    labels = {"instance": instance["instance_id"], "role": role}
    targets["nodes.json"].append(
        {"targets": [f"{address}:9100"], "labels": labels}
    )
    targets["containers.json"].append(
        {"targets": [f"{address}:8080"], "labels": labels}
    )
    if role == "Manager":
        targets["demo-app.json"].append(
            {"targets": [f"{address}:8081"], "labels": labels}
        )

for filename, groups in targets.items():
    fd, temporary = tempfile.mkstemp(dir=directory, prefix=filename)
    with os.fdopen(fd, "w") as stream:
        json.dump(groups, stream)
        stream.write("\n")
    destination = os.path.join(directory, filename)
    os.chmod(temporary, 0o644)
    os.replace(temporary, destination)
' "$TARGET_DIR"
