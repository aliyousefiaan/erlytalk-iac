project     = "erlytalk"
environment = "dev"

aws_region = "us-east-1"

vpc_main_cidr = "172.16.0.0/16"

ec2_general_config = {
  public_ssh_port = "5161"
  user_data       = <<-EOF
#cloud-config
# vim:syntax=yaml
disable_root: false
chpasswd:
  list: |
     root:tn8jxNqHr9z1e8mbzt8gv7mY5
  expire: False
runcmd:
  - userdel ubuntu
  - sed -i "s/#Port 22/Port 5161/" /etc/ssh/sshd_config
  - systemctl restart sshd
  EOF
}
keypair_default = {
  name       = "default"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDH3V3/caQMpsSux2jlidjbjD6DqyG0SRvoO+A3W42dStZTI6mQwoMG+e9np05G8kuEYZPEngfgVxnx37UBpWfbhdMUCqIzi2fGwtFww/aSGKw0GT/EGruH4nCKfnGcxgfU0IOkUigiBWlAvizCzqr7G7L0JqMA99NnKsAFCiWD39jctvwqg7ptm3bt2JbIC9xkllF+293AXLh0AVvFAnLIynmMyCWzceTWuSWbM3fsrVJyKudDwlUjksCra3SXiJVz9eYWO1JUre+iDGttqu7tqFePs8BPt27LuNs4fTmYd3UXYFfpkNU6mqh7AiBEyTCbkmVNEE9muC/esghD3VM7Pek7YupD6KK+czvIpFd2XrdiBR9g10yY2I9uS7YCM+FQu3cfqtZ4eRefqE4Od4Z/Bzjw7ZQxFBj5ctC+2GD5Bp28oPzPbsKvZStFMqwTbYOXV3sUxx9//1HoE2s0L8CQmTtTY1+43G1Hd2SwLITycDB25H+szDxukEl/aEIpj5s= dev_keypair_default"
}

internal_domain = "erlytalk.dev"

public_domain = "erlytalk.myclnet.com"

eks_main_managed_node_group_general_settings = {
  desired_size   = 3
  min_size       = 2
  max_size       = 5
  instance_types = ["t3.small"]
  capacity_type  = "ON_DEMAND"
}

eks_main_cert_manager_cluster_issuers = [
  {
    name        = "letsencrypt-staging"
    acme_server = "https://acme-staging-v02.api.letsencrypt.org/directory"
    acme_email  = "ssl@erlytalk.myclnet.com"
  },
  {
    name        = "letsencrypt-prod"
    acme_server = "https://acme-v02.api.letsencrypt.org/directory"
    acme_email  = "ssl@erlytalk.myclnet.com"
  }
]
