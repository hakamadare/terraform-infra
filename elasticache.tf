resource "aws_elasticache_cluster" "redis" {
  cluster_id               = "redis"
  engine                   = "redis"
  node_type                = "cache.t4g.micro"
  num_cache_nodes          = 1
  parameter_group_name     = aws_elasticache_parameter_group.redis.name
  engine_version           = "7.0"
  port                     = 6379
  apply_immediately        = true
  snapshot_retention_limit = 0
  subnet_group_name        = module.vpc.elasticache_subnet_group_name
  security_group_ids       = [aws_security_group.redis.id]
  tags                     = local.tags_all
}

resource "aws_elasticache_parameter_group" "redis" {
  name   = "redis7"
  family = "redis7"
  tags   = local.tags_all
}

resource "aws_security_group" "redis" {
  name_prefix = "redis-"
  description = "ElastiCache Redis cluster"
  vpc_id      = local.vpc_id
  tags        = local.tags_all
}

resource "aws_security_group_rule" "redis_ingress" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.ec2_ecs.id
  security_group_id        = aws_security_group.redis.id
}

resource "aws_security_group_rule" "redis_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.redis.id
}
