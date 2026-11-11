variable "aws_region" {
  description = "Region AWS donde se despliega la actividad"
  type        = string
  default     = "us-east-1"
}

variable "prefijo" {
  description = "Prefijo para nombrar todos los recursos"
  type        = string
  default     = "docker-swarm"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 (Academy: t2.micro/t3.micro; t3.small = 2 GiB)"
  type        = string
  default     = "t3.small"
}

variable "instance_profile_name" {
  description = "Instance profile existente del laboratorio (envuelve LabRole y habilita SSM)"
  type        = string
  default     = "LabInstanceProfile"
}

variable "root_volume_gb" {
  description = "Tamano del disco raiz en GB"
  type        = number
  default     = 30
}

variable "observability_instance_type" {
  description = "Tipo de instancia para Prometheus, Grafana y Loki"
  type        = string
  default     = "t3.small"
}

variable "observability_volume_gb" {
  description = "Tamano del volumen persistente de observabilidad en GB"
  type        = number
  default     = 20
}

variable "worker_desired_capacity" {
  description = "Cantidad deseada de workers del Docker Swarm"
  type        = number
  default     = 1
}

variable "worker_min_size" {
  description = "Cantidad minima de workers del Docker Swarm"
  type        = number
  default     = 1
}

variable "worker_max_size" {
  description = "Cantidad maxima de workers del Docker Swarm"
  type        = number
  default     = 2
}

variable "proxy_backend_port" {
  description = "Puerto HTTP publicado por la aplicacion en el routing mesh del Swarm"
  type        = number
  default     = 80

  validation {
    condition     = var.proxy_backend_port >= 1 && var.proxy_backend_port <= 65535
    error_message = "proxy_backend_port debe estar entre 1 y 65535."
  }
}

variable "vpc_id" {
  description = "VPC existente donde desplegar SGs e instancias"
  type        = string
  default     = "vpc-011f05a372ed4cffa"
}