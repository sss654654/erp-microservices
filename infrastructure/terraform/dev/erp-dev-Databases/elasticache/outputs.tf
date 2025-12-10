output "endpoint" { value = aws_elasticache_cluster.redis.cache_nodes[0].address }
output "arn" { value = aws_elasticache_cluster.redis.arn }
