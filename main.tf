provider "aws" {
  region = "ap-south-1"
  access_key = "AKIAZB646SZMKJ35BV7L"
  secret_key = "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"
}

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
