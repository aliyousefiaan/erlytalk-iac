resource "aws_route53_zone" "internal_domain" {
  name = var.internal_domain
  vpc {
    vpc_id = module.vpc_main.vpc_id
  }
}

data "aws_route53_zone" "public_domain" {
  name = var.public_domain
}
