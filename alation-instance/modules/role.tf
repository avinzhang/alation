resource "aws_iam_instance_profile" "e2_profile" {
  name = "${var.ec2_instance_name}-profile"
  role = var.aws_role
}


