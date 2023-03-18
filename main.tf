provider "aws" {
  region = "ap-south-1"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

variable "AWS_ACCESS_KEY_ID" {}

variable "AWS_SECRET_ACCESS_KEY" {}

resource "aws_ecr_repository" "demo_app" {
  name                 = "demo_app"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecs_cluster" "demo_app" {
  name = "demo_app"

  capacity_providers = ["FARGATE"]
}

resource "aws_ecs_task_definition" "demo_app" {
  family                   = "demo_app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  container_definitions    = jsonencode([{
    name      = "demo_app"
    image     = "622696765016.dkr.ecr.ap-south-1.amazonaws.com/demo_app:latest"
    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]
  }])
}

resource "aws_vpc" "demo_app" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "demo_app"
  }
}

resource "aws_security_group" "demo_app" {
  name_prefix = "demo_app_sg_"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

resource "aws_subnet" "demo_app" {
  count = length(var.availability_zones)

  cidr_block = "10.0.${count.index + 1}.0/24"
  availability_zone = "${var.availability_zones[count.index]}"
  vpc_id     = aws_vpc.demo_app.id
}

resource "aws_ecs_service" "demo_app" {
  name            = "demo_app"
  cluster         = aws_ecs_cluster.demo_app.id
  task_definition = aws_ecs_task_definition.demo_app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    security_groups = [aws_security_group.demo_app.id]
    subnets         = aws_subnet.demo_app.*.id
  }
}
