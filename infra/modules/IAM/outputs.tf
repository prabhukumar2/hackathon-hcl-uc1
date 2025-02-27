output "lambda_role_arn" {
  value = aws_iam_role.lambda_exec_role.arn
}

output "attach_basic_execution" {
    value = aws_iam_role_policy_attachment.lambda_exec_policy_attachment
}

