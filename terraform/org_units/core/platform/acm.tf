

resource "aws_acm_certificate" "platform" {
  domain_name               = "*.${local.subdomain}"
  subject_alternative_names = [local.subdomain]
  validation_method         = "DNS"
  tags                      = local.tags
}


resource "aws_route53_record" "platform" {
  for_each = {
    for dvo in aws_acm_certificate.platform.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.platform.zone_id
}

resource "aws_acm_certificate_validation" "platform" {
  certificate_arn         = aws_acm_certificate.platform.arn
  validation_record_fqdns = [for record in aws_route53_record.platform : record.fqdn]
}

output "cert_arn" {
  value = aws_acm_certificate.platform.arn
}


