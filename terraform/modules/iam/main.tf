resource "aws_iam_role" "monitoring_role" {

  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

}
resource "aws_iam_role_policy_attachment" "ec2_readonly" {

  role = aws_iam_role.monitoring_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"

}
resource "aws_iam_instance_profile" "monitoring_profile" {

  name = "${var.role_name}-profile"

  role = aws_iam_role.monitoring_role.name

}
