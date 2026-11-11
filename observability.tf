resource "aws_instance" "observability" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.observability_instance_type
  subnet_id                   = data.aws_subnets.public.ids[0]
  vpc_security_group_ids      = [aws_security_group.observability.id]
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/scripts/user-data-observability.sh", {
    aws_region  = var.aws_region
    compose_b64 = base64encode(file("${path.module}/monitoring/docker-compose.yml"))
    prometheus_b64 = base64encode(templatefile("${path.module}/monitoring/prometheus.yml.tftpl", {
      aws_region   = var.aws_region
      project_name = var.prefijo
    }))
    loki_b64                    = base64encode(file("${path.module}/monitoring/loki.yml"))
    project_name                = var.prefijo
    targets_refresh_b64         = base64encode(file("${path.module}/monitoring/refresh-targets.sh"))
    datasources_b64             = base64encode(file("${path.module}/monitoring/grafana/provisioning/datasources/datasources.yml"))
    dashboards_provisioning_b64 = base64encode(file("${path.module}/monitoring/grafana/provisioning/dashboards/dashboards.yml"))
    dashboard_b64               = base64encode(file("${path.module}/monitoring/grafana/dashboards/swarm-overview.json"))
  })

  root_block_device {
    volume_size = var.observability_volume_gb
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name    = "${var.prefijo}-observability"
    Project = var.prefijo
    Role    = "Observability"
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "aws_ecr_repository" "demo_app" {
  name                 = "${var.prefijo}-demo-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.prefijo}-demo-app"
  }
}

resource "aws_ecr_lifecycle_policy" "demo_app" {
  repository = aws_ecr_repository.demo_app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the most recent 10 demo images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_repository_policy" "demo_app" {
  repository = aws_ecr_repository.demo_app.name
  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [{
      Sid    = "AllowSwarmInstancesToPushDemoImage"
      Effect = "Allow"
      Principal = {
        AWS = data.aws_iam_instance_profile.lab.role_arn
      }
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ]
    }]
  })
}
