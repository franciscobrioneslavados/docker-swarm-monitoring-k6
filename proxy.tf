resource "aws_instance" "traefik" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.public.ids[0]
  vpc_security_group_ids      = [aws_security_group.proxy.id]
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/scripts/user-data-traefik.sh", {
    project_name = var.prefijo
    aws_region   = var.aws_region
    backend_port = var.proxy_backend_port
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.prefijo}-traefik"
    Project = var.prefijo
    Role    = "Proxy"
  }
}
