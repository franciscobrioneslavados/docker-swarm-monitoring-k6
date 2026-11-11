resource "aws_ssm_parameter" "swarm_worker_token" {
  name        = "/${var.prefijo}/swarm/worker-token"
  description = "Docker Swarm worker join token"
  type        = "SecureString"
  value       = "pending"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_instance" "swarm_manager" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.public.ids[1]
  vpc_security_group_ids      = [aws_security_group.swarm.id]
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/scripts/user-data-swarm.sh", {
    node_role       = "manager"
    project_name    = var.prefijo
    aws_region      = var.aws_region
    token_parameter = aws_ssm_parameter.swarm_worker_token.name
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.prefijo}-manager"
    Project = var.prefijo
    Role    = "Manager"
  }
}

resource "aws_launch_template" "swarm_worker" {
  name_prefix   = "${var.prefijo}-worker-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  network_interfaces {
    security_groups             = [aws_security_group.swarm.id]
    associate_public_ip_address = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/user-data-swarm.sh", {
    node_role       = "worker"
    project_name    = var.prefijo
    aws_region      = var.aws_region
    token_parameter = aws_ssm_parameter.swarm_worker_token.name
  }))

  block_device_mappings {
    device_name = data.aws_ami.ubuntu.root_device_name

    ebs {
      volume_size = var.root_volume_gb
      volume_type = "gp3"
    }
  }

}

resource "aws_autoscaling_group" "swarm_workers" {
  name                = "${var.prefijo}-workers"
  desired_capacity    = var.worker_desired_capacity
  max_size            = var.worker_max_size
  min_size            = var.worker_min_size
  vpc_zone_identifier = data.aws_subnets.public.ids

  launch_template {
    id      = aws_launch_template.swarm_worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.prefijo}-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.prefijo
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "Worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }

  lifecycle {
    precondition {
      condition = (
        var.worker_min_size <= var.worker_desired_capacity &&
        var.worker_desired_capacity <= var.worker_max_size
      )
      error_message = "worker_desired_capacity debe estar entre worker_min_size y worker_max_size."
    }
  }

  depends_on = [aws_instance.swarm_manager]
}
