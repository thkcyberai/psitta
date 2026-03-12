# ── Security Group for RDS ────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "Allow PostgreSQL access from within VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-rds-sg" }
}

# ── Subnet Group ─────────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = { Name = "${var.project}-db-subnet-group" }
}

# ── RDS PostgreSQL ────────────────────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier        = "${var.project}-db"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_encrypted = true

  db_name  = "psitta"
  username = "psitta"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.project}-db-final-snapshot"

  tags = {
    Name        = "${var.project}-db"
    Project     = var.project
    Environment = var.environment
  }
}
