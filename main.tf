provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "${var.name}-vpc" }
}

resource "aws_subnet" "public" {
  count = 2
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.${count.index}.0/24"
  availability_zone = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true
  tags = { Name = "${var.name}-subnet-${count.index}" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "${var.name}-route-table" }
}

resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.main.id
  name = "${var.name}-alb-sg"
  description = "Allow HTTP"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.name}-alb-sg" }
}

resource "aws_lb" "app" {
  name = "${var.name}-alb"
  internal = false
  load_balancer_type = "application"
  subnets = aws_subnet.public[*].id
  security_groups = [aws_security_group.alb.id]
  tags = { Name = "${var.name}-alb" }
}

resource "aws_lb_target_group" "ecs" {
  name = "${var.name}-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/"
    protocol = "HTTP"
  }
  tags = { Name = "${var.name}-tg" }
}

resource "aws_lb_listener" "front" {
  load_balancer_arn = aws_lb.app.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-ecs-cluster"
}

resource "aws_ecs_task_definition" "nginx" {
  family = "${var.name}-nginx"
  cpu = "256"
  memory = "512"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  container_definitions = jsonencode([{
    name = "nginx"
    image = "nginx:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort = 80
      protocol = "tcp"
    }]
  }])
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.name}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_role_assume_role_policy.json
}

data "aws_iam_policy_document" "ecs_execution_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_security_group" "ecs" {
  vpc_id = aws_vpc.main.id
  name = "${var.name}-ecs-sg"
  description = "Allow HTTP from ALB"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.name}-ecs-sg" }
}

resource "aws_ecs_service" "main" {
  name = "${var.name}-ecs-service"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count = 1
  launch_type = "FARGATE"
  network_configuration {
    subnets = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name = "nginx"
    container_port = 80
  }
  depends_on = [aws_lb_listener.front]
}
