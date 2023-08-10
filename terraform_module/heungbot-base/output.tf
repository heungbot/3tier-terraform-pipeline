output "public_subnet_ids" {
  description = "public subnet's id list"
  value       = aws_subnet.public.*.id
}

output "private_subnets_ids" {
  description = "private subnet's id list"
  value       = aws_subnet.private.*.id
}

output "main_target_group_arn" {
  value = aws_lb_target_group.main-target-group.arn
}

output "backend_ecs_service_sg_id" {
  value = aws_security_group.backend-service-security-group.id
}

# FOR DATABASE
output "DB_SUBNET_GROUP_NAME" {
  value = aws_db_subnet_group.rds-subnet-group.name
}

output "CACHE_SUBNET_GROUP_NAME" {
  value = aws_elasticache_subnet_group.cache-subnet-group.name
}

output "DB_SG_IDS" {
  value = flatten(tolist([aws_security_group.rds-security-group.id]))
}

output "CACHE_SG_IDS" {
  value = flatten(tolist([aws_security_group.cache-security-group.id]))
}

output "DB_SUBNET_IDS" {
  value = flatten(tolist(aws_subnet.db.*.id))
}





# output "backend_target_group_arn" {
#   value = aws_lb_target_group.backend-target-group.arn
# }

# output "frontend_ecs_service_sg_id" {
#   value = aws_security_group.frontend-service-security-group.id
# }