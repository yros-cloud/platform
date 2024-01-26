locals {
  subdomain = "${var.env}.${var.domain_name}"
  tags = {
    project     = var.project
    environment = "${var.env}"
    ou          = var.organization_unit
  }
}