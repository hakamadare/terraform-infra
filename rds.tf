locals {
  db_identifier = "postgres"
}

module "postgres" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5"

  identifier = local.db_identifier

  engine               = "postgres"
  engine_version       = "14.3"
  major_engine_version = "14"
  family               = "postgres14"

  instance_class        = "db.t4g.micro"
  allocated_storage     = 5
  max_allocated_storage = 100

  db_name                = "postgres"
  username               = "postgres"
  create_random_password = true
  random_password_length = 64

  multi_az = false

  create_db_subnet_group = false
  db_subnet_group_name   = module.vpc.database_subnet_group_name

  deletion_protection = true

  create_db_parameter_group       = true
  parameter_group_name            = local.db_identifier
  parameter_group_use_name_prefix = true

  vpc_security_group_ids = [data.aws_security_group.ec2_ecs.id]

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  backup_retention_period = 3
  storage_encrypted       = true

  performance_insights_enabled           = true
  performance_insights_retention_period  = 7
  create_monitoring_role                 = true
  monitoring_interval                    = 60
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = 3

  tags = local.tags_all
}

resource "aws_ssm_parameter" "postgres_master_password" {
  name        = "/postgres/master_password"
  description = "Master password for postgres"
  type        = "SecureString"
  value       = module.postgres.db_instance_password
}
