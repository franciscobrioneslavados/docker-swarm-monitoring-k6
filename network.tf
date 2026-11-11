resource "aws_security_group" "swarm" {
  name        = "${var.prefijo}-swarm-sg"
  description = "Docker Swarm node communication"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    self        = true
    description = "Swarm management"
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    self        = true
    description = "Swarm node communication TCP"
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    self        = true
    description = "Swarm node communication UDP"
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = true
    description = "Swarm overlay network"
  }

  ingress {
    from_port       = var.proxy_backend_port
    to_port         = var.proxy_backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.proxy.id]
    description     = "Application traffic from Traefik"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = [ingress]
  }

  tags = {
    Name = "${var.prefijo}-swarm-sg"
  }
}

resource "aws_security_group" "proxy" {
  name        = "${var.prefijo}-traefik-sg"
  description = "Public HTTP access to Traefik"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefijo}-traefik-sg"
  }
}

resource "aws_security_group" "observability" {
  name        = "${var.prefijo}-observability-sg"
  description = "Grafana HTTPS and private metrics/log ingestion"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana HTTPS with generated admin credentials"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = [ingress]
  }

  tags = {
    Name = "${var.prefijo}-observability-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "observability_loki_from_swarm" {
  security_group_id            = aws_security_group.observability.id
  referenced_security_group_id = aws_security_group.swarm.id
  from_port                    = 3100
  to_port                      = 3100
  ip_protocol                  = "tcp"
  description                  = "Loki log ingestion from Swarm nodes"
}

resource "aws_vpc_security_group_ingress_rule" "swarm_node_exporter_from_observability" {
  security_group_id            = aws_security_group.swarm.id
  referenced_security_group_id = aws_security_group.observability.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
  description                  = "Prometheus node exporter scraping"
}

resource "aws_vpc_security_group_ingress_rule" "swarm_cadvisor_from_observability" {
  security_group_id            = aws_security_group.swarm.id
  referenced_security_group_id = aws_security_group.observability.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "Prometheus cAdvisor scraping"
}

resource "aws_vpc_security_group_ingress_rule" "swarm_demo_metrics_from_observability" {
  security_group_id            = aws_security_group.swarm.id
  referenced_security_group_id = aws_security_group.observability.id
  from_port                    = 8081
  to_port                      = 8081
  ip_protocol                  = "tcp"
  description                  = "Prometheus demo application metrics scraping"
}
