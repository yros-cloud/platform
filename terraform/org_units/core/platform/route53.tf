data "aws_route53_zone" "root" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_zone" "platform" {
  name = local.subdomain
  comment       = "Hosted Zone for ${var.project} ${var.env}"
  
  tags = {
    managed-by  = "terraform"
    environment = "${var.env}"
    OU          = var.organization_unit
  }
}

resource "aws_route53_record" "ns_record" {
  type    = "NS"
  zone_id = "${data.aws_route53_zone.root.id}"
  name    = "dev"
  ttl     = "86400"
  records = aws_route53_zone.platform.name_servers
}