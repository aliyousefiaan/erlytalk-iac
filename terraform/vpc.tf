module "vpc_main" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0.2"

  name = "main-${var.environment}"
  cidr = var.vpc_main_cidr

  azs = [
    "${var.aws_region}${var.az_suffixes[0]}",
    "${var.aws_region}${var.az_suffixes[1]}"
  ]

  public_subnets = [
    cidrsubnet(var.vpc_main_cidr, 4, 0),
    cidrsubnet(var.vpc_main_cidr, 4, 1)
  ]

  private_subnets = [
    cidrsubnet(var.vpc_main_cidr, 4, 3),
    cidrsubnet(var.vpc_main_cidr, 4, 4)
  ]

  intra_subnets = [
    cidrsubnet(var.vpc_main_cidr, 4, 6),
    cidrsubnet(var.vpc_main_cidr, 4, 7)
  ]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}
