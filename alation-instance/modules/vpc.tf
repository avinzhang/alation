resource "aws_security_group" "ec2_security_groups" {
  name   = "${var.ec2_instance_name}-sg"
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.ec2_instance_name}-sg"
  }
}

resource "aws_security_group_rule" "ingress_rules" {
  count = length(var.ec2_ingress_rules)

  type              = "ingress"
  from_port         = var.ec2_ingress_rules[count.index].from_port
  to_port           = var.ec2_ingress_rules[count.index].to_port
  protocol          = var.ec2_ingress_rules[count.index].protocol
  cidr_blocks       = [var.ec2_ingress_rules[count.index].cidr_block]
  security_group_id = aws_security_group.ec2_security_groups.id
}


resource "aws_security_group_rule" "egress_rules" {
  count = length(var.ec2_egress_rules)

  type              = "egress"
  from_port         = var.ec2_egress_rules[count.index].from_port
  to_port           = var.ec2_egress_rules[count.index].to_port
  protocol          = var.ec2_egress_rules[count.index].protocol
  cidr_blocks       = [var.ec2_egress_rules[count.index].cidr_block]
  security_group_id = aws_security_group.ec2_security_groups.id
}
