output "instances_config" {
  description = "IDs y direcciones IP de las instancias del Swarm"
  value = {
    manager = {
      id         = aws_instance.swarm_manager.id
      public_ip  = aws_instance.swarm_manager.public_ip
      private_ip = aws_instance.swarm_manager.private_ip
    }
    workers = {
      desired_capacity = aws_autoscaling_group.swarm_workers.desired_capacity
      running_count    = length(data.aws_instances.swarm_workers.ids)
      instance_ids     = data.aws_instances.swarm_workers.ids
      public_ips       = data.aws_instances.swarm_workers.public_ips
      private_ips      = data.aws_instances.swarm_workers.private_ips
    }
    traefik = {
      id         = aws_instance.traefik.id
      public_ip  = aws_instance.traefik.public_ip
      private_ip = aws_instance.traefik.private_ip
    }
  }
}

output "observability_instance_id" {
  description = "EC2 instance ID for Grafana, Prometheus, and Loki"
  value       = aws_instance.observability.id
}

output "observability_public_url" {
  description = "HTTPS URL for Grafana (self-signed certificate)"
  value       = "https://${aws_instance.observability.public_ip}:3000"
}

output "observability_private_ip" {
  description = "Private IP used by Swarm agents to send logs"
  value       = aws_instance.observability.private_ip
}

output "swarm_manager_instance_id" {
  description = "Manager instance ID for SSM deployments"
  value       = aws_instance.swarm_manager.id
}

output "app_repository_url" {
  description = "ECR repository for the demo application image"
  value       = aws_ecr_repository.demo_app.repository_url
}
