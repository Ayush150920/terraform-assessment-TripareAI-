########################################
# RDS module: private PostgreSQL reachable ONLY from ECS tasks
########################################

# Generated master password. In production, source this from AWS Secrets
# Manager or SSM Parameter Store instead of Terraform state.
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#%*()-_=+[]{}:?"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-db-subnets" })
}

# RDS security group: ingress permitted ONLY from the ECS tasks' security group.
resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "RDS security group: allow DB traffic only from ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB port from ECS tasks only"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-rds-sg" })
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-db"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = var.storage_encrypted

  db_name  = var.db_name
  username = var.username
  password = random_password.db.result
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # never expose RDS to the internet
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-db-final"

  apply_immediately = true

  tags = merge(var.tags, { Name = "${var.name}-db" })
}
