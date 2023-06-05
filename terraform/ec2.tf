# Ubuntu22.04 ami
data "aws_ami" "ubuntu2204" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "default" {
  key_name   = "${var.keypair_default["name"]}-${var.environment}"
  public_key = var.keypair_default["public_key"]

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

# EC2 - mgmt
module "security_group_ec2_mgmt" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0.0"

  name   = "ec2-mgmt-${var.environment}"
  vpc_id = module.vpc_main.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = var.ec2_general_config["public_ssh_port"]
      to_port     = var.ec2_general_config["public_ssh_port"]
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_rules = ["all-all"]

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

module "ec2_mgmt" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.1.0"

  name = "mgmt-${var.environment}"

  ami           = data.aws_ami.ubuntu2204.id
  instance_type = "t2.micro"

  availability_zone      = element(module.vpc_main.azs, 0)
  subnet_id              = element(module.vpc_main.public_subnets, 0)
  vpc_security_group_ids = [module.security_group_ec2_mgmt.security_group_id]

  user_data = var.ec2_general_config["user_data"]
  key_name  = aws_key_pair.default.key_name

  root_block_device = [
    {
      volume_type           = "gp2"
      volume_size           = 20
      delete_on_termination = true
    },
  ]

  ignore_ami_changes = true

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_eip" "ec2_mgmt" {
  instance = module.ec2_mgmt.id
  domain   = "vpc"

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_route53_record" "ec2_mgmt" {
  zone_id = data.aws_route53_zone.public_domain.zone_id
  name    = format("mgmt.infra.%s", data.aws_route53_zone.public_domain.name)
  type    = "A"
  records = [aws_eip.ec2_mgmt.public_ip]
  ttl     = 60
}
