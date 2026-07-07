project     = "devops-assessment"
environment = "dev"
aws_region  = "us-east-1"

# --- Network (smaller footprint, 2 AZs) ---
vpc_cidr             = "10.10.0.0/16"
azs                  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24"]
private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]

# --- ECS / app (minimal sizing) ---
container_image = "nginx:1.27-alpine"
container_port  = 80
desired_count   = 1
task_cpu        = "256"
task_memory     = "512"

# --- RDS (small instance, short retention, no deletion protection) ---
db_engine                  = "postgres"
db_engine_version          = "16.4"
db_instance_class          = "db.t3.micro"
db_allocated_storage       = 20
db_max_allocated_storage   = 50
db_name                    = "bookings"
db_username                = "app_admin"
db_multi_az                = false
db_backup_retention_period = 1
db_deletion_protection     = false
db_skip_final_snapshot     = true
