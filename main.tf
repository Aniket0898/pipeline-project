provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAZB646SZMKJ35BV7L"
  secret_key = "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"
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
    subnets          = ["subnet-0df53af7aba1ca7b0", "subnet-0d9076e31da33798c", "subnet-048dc467d2005bd7c"]
  }
}

resource "aws_ecs_task_definition" "taskdefinition" {
  family                   = "demo_task"
  container_definitions    = jsonencode([
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
    }
  ])
  requires_compatibilities = ["FARGATE"]  
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.demo_app_task_execution_role.arn
  task_role_arn            = aws_iam_role.demo_app_task_execution_role.arn
  cpu                      = "1024"
  memory                   = "3072"
}

resource "aws_iam_role" "demo_app_task_execution_role" {
  name = "demo_app-task-execution-role"

  assume_role_policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
        {
            Effect: "Allow",
            Principal: {
                Service: "ecs-tasks.amazonaws.com"
            },
            Action: "sts:AssumeRole"
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
