resource "aws_route53_record" "public" {
  count = var.lb_enabled ? 1 : 0
  zone_id = var.zone_id_public
  name    = var.dns_name
  type    = "CNAME"
  ttl = "60"
  records        = [aws_lb.alation[count.index].dns_name]
}

resource "aws_route53_record" "private" {
  count = var.lb_enabled ? 1 : 0
  zone_id = var.zone_id_private
  name    = var.dns_name
  type    = "CNAME"
  ttl = "60"
  records        = [aws_lb.alation[count.index].dns_name]
}
