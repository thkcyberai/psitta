# -- Security Group for RDS --------------------------------------------------
#
# Ingress is intentionally NOT defined inline. All ingress rules are managed
# via separate aws_vpc_security_group_ingress_rule resources so they coexist
# cleanly with the per-Lambda SG-scoped rules added by lambda_*.tf files.
# (An inline ingress block would conflict with separate rule resources on
# every terraform apply -- Terraform reconciles the SG by removing rules
# that aren't in the inline block, including SG-scoped rules added elsewhere.)
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "Allow PostgreSQL access from within VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-rds-sg" }
}

# Internal VPC ingress -- replaces the previously-inline ingress block.
# depends_on enforces that aws_security_group.rds is modified FIRST (inline
# block removed) before this resource is created. Otherwise AWS rejects
# AuthorizeSecurityGroupIngress with InvalidPermission.Duplicate because
# the inline-block rule and this resource describe the identical rule
# (CIDR 10.0.0.0/16, port 5432, tcp). The ordering produces a sub-second
# window where the CIDR rule is absent; established RDS connections from
# ECS survive (SGs are stateful at connection-establishment time); new
# connection attempts in the gap can transiently fail and would retry.
resource "aws_vpc_security_group_ingress_rule" "rds_internal_cidr" {
  security_group_id = aws_security_group.rds.id
  cidr_ipv4         = "10.0.0.0/16"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "VPC internal Postgres ingress (10.0.0.0/16:5432)"

  depends_on = [aws_security_group.rds]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
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

  # Enables the IAM auth path for Lambdas / ECS using rds-db:connect.
  # Password auth (e.g. master user `psitta`) continues to work.
  # Per-user opt-in still required: each Postgres role must hold the
  # `rds_iam` role grant (handled in db_bootstrap for psitta_api_digest).
  iam_database_authentication_enabled = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project}-db-final-snapshot"

  tags = {
    Name        = "${var.project}-db"
    Project     = var.project
    Environment = var.environment
  }
}
