project     = "devops-assessment"
environment = "prod"
aws_region  = "us-east-1"

# --- Network (larger footprint, 3 AZs) ---
vpc_cidr             = "10.20.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]

# --- ECS / app (HA sizing) ---
container_image = "nginx:1.27-alpine"
container_port  = 80
desired_count   = 3
task_cpu        = "1024"
task_memory     = "2048"

# --- RDS (larger instance, multi-AZ, long retention, deletion protection on) ---
db_engine                  = "postgres"
db_engine_version          = "16.4"
db_instance_class          = "db.r6g.large"
db_allocated_storage       = 100
db_max_allocated_storage   = 500
db_name                    = "bookings"
db_username                = "app_admin"
db_multi_az                = true
db_backup_retention_period = 30
db_deletion_protection     = true
db_skip_final_snapshot     = false
