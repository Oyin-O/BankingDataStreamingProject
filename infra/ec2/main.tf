# ─────────────────────────────────────────
# TERRAFORM CONFIG
# ─────────────────────────────────────────
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────
# DATA SOURCES
# ─────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_vpc" "default" {
  default = true
}

# ─────────────────────────────────────────
# SECURITY GROUP
# ─────────────────────────────────────────
resource "aws_security_group" "banking_pipeline" {
  name        = "banking-pipeline-sg"
  description = "Security group for banking data pipeline"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    description = "Airflow UI"
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    description = "Kafka UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    description = "Spark UI"
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "banking-pipeline-sg"
    Project = "banking-data-platform"
  }
}

# ─────────────────────────────────────────
# KEY PAIR
# ─────────────────────────────────────────
resource "aws_key_pair" "banking_pipeline" {
  key_name   = "banking-pipeline-key"
  public_key = file(var.ssh_public_key_path)
}

# ─────────────────────────────────────────
# EC2 INSTANCE
# ─────────────────────────────────────────
resource "aws_instance" "banking_pipeline" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.banking_pipeline.key_name
  vpc_security_group_ids = [aws_security_group.banking_pipeline.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get upgrade -y

    # Install Docker
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable"
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Add ubuntu user to docker group
    usermod -aG docker ubuntu

    # Install git and other tools
    apt-get install -y git gettext-base python3-pip

    # Install python-dotenv
    pip3 install python-dotenv

    # Create project directory
    mkdir -p /home/ubuntu/banking-pipeline
    chown ubuntu:ubuntu /home/ubuntu/banking-pipeline

    echo "Setup complete!" > /home/ubuntu/setup.log
  EOF

  tags = {
    Name    = "banking-pipeline"
    Project = "banking-data-platform"
  }
}

# ─────────────────────────────────────────
# ELASTIC IP
# ─────────────────────────────────────────
resource "aws_eip" "banking_pipeline" {
  instance = aws_instance.banking_pipeline.id
  domain   = "vpc"

  tags = {
    Name = "banking-pipeline-eip"
  }
}

# ─────────────────────────────────────────
# OUTPUTS
# ─────────────────────────────────────────
output "instance_public_ip" {
  value = aws_eip.banking_pipeline.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.banking_pipeline.public_ip}"
}