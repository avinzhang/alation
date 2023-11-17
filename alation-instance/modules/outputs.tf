output "ec2-primary-instance-id" {
  value = "${aws_instance.primary[*].id}"
}

output "ec2-primary-public-ip" {
  value = "${aws_instance.primary[*].public_ip}"
}
