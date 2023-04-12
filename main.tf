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
  name_prefix = "demo_app"
  vpc_id      = aws_vpc.demo_app.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = "ecs_logs"

  tags = {
    Name = "ecs_logs"
  }
} 

resource "aws_cloudwatch_log_stream" "ecs_logs_demo_container" {
  name           = "demo_container"
  log_group_name = aws_cloudwatch_log_group.ecs_logs.name
}

resource "aws_ecr_repository" "demo_repo" {
  name = "demo_repo"
}

resource "aws_ecs_cluster" "demo_app" {
  name = "demo_app"
}

resource "aws_ecs_service" "service" {
  name = "demo_service"
  cluster                = aws_ecs_cluster.demo_app.arn
  launch_type            = "FARGATE"
  enable_execute_command = true

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  task_definition                    = aws_ecs_task_definition.taskdefinition.arn

  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.demo_app.id]
    subnets          = [aws_subnet.demo_app-public-1.id, aws_subnet.demo_app-public-2.id]
  }
}

resource "aws_ecs_task_definition" "taskdefinition" {
    family                = "demo_container"
    container_definitions = jsonencode([
      {
        name         = "demo_container"
        image        = "622696765016.dkr.ecr.ap-south-1.amazonaws.com/demo_repo"
        cpu          = 1024
        memory       = 3072
        essential    = true
        portMappings = [
          {
            containerPort = 3000
            hostPort      = 3000
          }
       ]
       logConfiguration = {
        logDriver = "awslogs",
        options   = {
          "awslogs-group"        = "aws_cloudwatch_log_group.ecs_logs.name"
          "awslogs-region"       = "ap-south-1"
          "awslogs-stream-prefix" = "demo_container"
        }
      }
    requires_compatibilities = ["FARGATE"]  
    cpu                      = "1024"
    memory                   = "3072"
    network_mode             = "awsvpc"
    execution_role_arn       = aws_iam_role.demo_app_task_execution_role.arn
    task_role_arn            = aws_iam_role.demo_app_task_execution_role.arn   
    }
   ])
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

  inline_policy {
    name = "ecs-task-permissions"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ecr:*",
            "ecs:*",
            "cloudwatch:*"
          ],
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_iam_policy" "cloudwatch_full_access" {
  name        = "cloudwatch_full_access"
  description = "Provides full access to CloudWatch"

  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "logs:*"
        ],
        Resource: "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_full_access_attachment" {
  policy_arn = "aws_iam_policy.cloudwatch_full_access.arn"
  role       = "aws_iam_role.demo_app_task_execution_role.name"
}

