resource "aws_lb" "alation" {
  count = var.lb_enabled ? 1 : 0
  name               = "${var.ec2_instance_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = concat(var.sg_ids,[aws_security_group.ec2_security_groups.id])
  subnets            = var.subnet_id
  enable_deletion_protection = false
  depends_on = [aws_lb_target_group.tg]


  tags = {
    Name = "${var.ec2_instance_name}-lb"
    Owner = var.owner
  }
}

resource "aws_lb_target_group" "tg" {
  count = var.lb_enabled ? 1 : 0
  name        = "${var.ec2_instance_name}-tg" 
  port        = 80
  target_type = "instance"
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  health_check {
    port     = "traffic-port"
    protocol = "HTTP"
    path = "/monitor/i_am_alive/"
  }

}

resource "aws_alb_target_group_attachment" "tgattachment" {
  count = var.lb_enabled ? 1 : 0
  target_group_arn = aws_lb_target_group.tg[count.index].arn
  target_id        = element(aws_instance.primary.*.id, count.index)
  port = 80
}

resource "aws_lb_listener" "https" {
  count = var.lb_enabled ? 1 : 0
  load_balancer_arn = aws_lb.alation[count.index].arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn = var.lb_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[count.index].arn
 }
}

resource "aws_lb_listener" "http" {
  count = var.lb_enabled ? 1 : 0
  load_balancer_arn = aws_lb.alation[count.index].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  depends_on = [aws_lb.alation ]
}

