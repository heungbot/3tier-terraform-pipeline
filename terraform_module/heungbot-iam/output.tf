output "TASK_EXECUTION_ROLE_ARN" {
    value = aws_iam_role.ecsTaskExecutionRole.arn
}