provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAZB646SZMKJ35BV7L"
  secret_key = "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"
}

resource "aws_vpc" "demo_app" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "demo_app-vpc"
  }
}

resource "aws_security_group" "demo_app" {
  name_prefix = "demo_app-"
  vpc_id      = aws_vpc.demo_app.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "demo_app-public-1" {
  vpc_id            = aws_vpc.demo_app.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "demo_app-public-2" {
  vpc_id            = aws_vpc.demo_app.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
}

resource "aws_ecr_repository" "demo_app" {
  name = "demo_app"
}

resource "aws_ecs_cluster" "demo_app" {
  name = "demo_app"
}

resource "aws_iam_role" "demo_app_task_execution_role" {
  name = "demo_app-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "demo_app_task_execution_policy" {
  name = "demo_app-task-execution-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ecs:*",
          "ecr:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "demo_app_task_execution_policy_attachment" {
  policy_arn = aws_iam_policy.demo_app_task_execution_policy.arn
  role       = aws_iam_role.demo_app_task_execution_role.id
}

resource "aws_ecs_task_definition" "demo_app" {
  family                   = "demo_app"
  cpu                      = 256
  memory = 512
  container_definitions    = jsonencode([{
    name  = "demo_app"
    image = aws_ecr_repository.demo_app.repository_url
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort = 3000
    }]
  }])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.demo_app_task_execution_role.arn
}
