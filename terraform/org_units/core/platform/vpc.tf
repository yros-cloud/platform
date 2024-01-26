
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.1"
  name    = "${var.project}-${var.env}"
  cidr    = "${var.network_prefix}.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["${var.network_prefix}.32.0/19", "${var.network_prefix}.64.0/19", "${var.network_prefix}.96.0/19"]
  public_subnets  = ["${var.network_prefix}.0.0/22", "${var.network_prefix}.4.0/22", "${var.network_prefix}.8.0/22"]

  enable_nat_gateway     = true
  enable_vpn_gateway     = false
  single_nat_gateway     = true
  enable_dns_support     = true
  enable_dns_hostnames   = true
  one_nat_gateway_per_az = false
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  tags = merge(
    {
      "kubernetes.io/cluster/${var.project}-${var.env}" = "owned"
    }
  )
}



