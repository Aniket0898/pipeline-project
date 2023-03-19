provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAZB646SZMKJ35BV7L"
  secret_key = "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"
}

resource "aws_vpc" "demoapp" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "demoapp-vpc"
  }
}

resource "aws_subnet" "demoapp_public_1" {
  vpc_id     = "${aws_vpc.demoapp.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "demoapp_public_2" {
  vpc_id     = "${aws_vpc.demoapp.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"
}

resource "aws_security_group" "ecs_tasks" {
  name_prefix = "ecs-tasks-"
  vpc_id      = "${aws_vpc.demoapp.id}"

  ingress {
    from_port   = 3000
    to_port     = 3000
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

resource "aws_ecr_repository" "demoapp" {
  name = "demoapp"
}

resource "aws_ecs_task_definition" "demoapp" {
  family                   = "demoapp"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "demoapp",
      "image": "${aws_ecr_repository.demoapp.repository_url}",
      "cpu": 256,
      "memory": 512,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ]
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
}


resource "aws_ecs_cluster" "demoapp" {
  name = "demoapp"
}

resource "aws_ecs_service" "demoapp" {
  name            = "demoapp"
  cluster         = "${aws_ecs_cluster.demoapp.id}"
  task_definition = "${aws_ecs_task_definition.demoapp.arn}"
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["${aws_subnet.demoapp_public_1.id}", "${aws_subnet.demoapp_public_2.id}"]
    security_groups  = ["${aws_security_group.ecs_tasks.id}"]
    assign_public_ip = "ENABLED"
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.demoapp.arn}"
  }
}
