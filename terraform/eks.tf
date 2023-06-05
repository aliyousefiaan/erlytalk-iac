# EKS - main
module "eks_main" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "main-${var.environment}"
  cluster_version = "1.27"

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc_main.vpc_id
  subnet_ids               = module.vpc_main.private_subnets
  control_plane_subnet_ids = module.vpc_main.intra_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    general-workers = {
      labels = {
        nodegroup = "general-workers"
      }

      desired_size = var.eks_main_managed_node_group_general_settings.desired_size
      min_size     = var.eks_main_managed_node_group_general_settings.min_size
      max_size     = var.eks_main_managed_node_group_general_settings.max_size

      instance_types = var.eks_main_managed_node_group_general_settings.instance_types
      capacity_type  = var.eks_main_managed_node_group_general_settings.capacity_type

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      node_security_group_additional_rules = {
        ingress_self_all = {
          description = "Node to node all ports/protocols"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          type        = "ingress"
          self        = true
        }
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled"                 = "1"
        "k8s.io/cluster-autoscaler/main-${var.environment}" = "1"
      }
    }
  }

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = module.iam_role_eks_main_admin.iam_role_arn
      username = module.iam_role_eks_main_admin.iam_role_name
      groups   = ["system:masters"]
    },
  ]

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

data "aws_eks_cluster" "main" {
  name = module.eks_main.cluster_name
  depends_on = [
    module.eks_main.eks_managed_node_groups,
  ]
}

resource "null_resource" "eks_main_kube_config" {
  depends_on = [module.eks_main]
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks_main.cluster_name} --kubeconfig ~/.kube/${var.project}-eks-main-${var.environment} --region ${var.aws_region}"
  }
}

# EKS - main - admin
module "iam_policy_eks_main_admin" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 5.20.0"

  name          = "eks-main-admin-${var.environment}"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

module "iam_role_eks_main_admin" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.20.0"

  role_name         = "eks-main-admin-${var.environment}"
  create_role       = true
  role_requires_mfa = false

  custom_role_policy_arns = [module.iam_policy_eks_main_admin.arn]

  trusted_role_arns = [
    "arn:aws:iam::${module.vpc_main.vpc_owner_id}:root"
  ]

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

module "iam_assume_policy_eks_main_admin" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 5.20.0"

  name          = "eks-main-admin-assume-${var.environment}"
  create_policy = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect   = "Allow"
        Resource = module.iam_role_eks_main_admin.iam_role_arn
      },
    ]
  })

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

module "iam_group_eks_main_admin" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "~> 5.20.0"

  name                              = "eks-main-admin-${var.environment}"
  attach_iam_self_management_policy = false
  create_group                      = true
  group_users                       = [] # Put the users here you want to access the eks cluster
  custom_group_policy_arns          = [module.iam_assume_policy_eks_main_admin.arn]

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

# EKS - main - metrics-server
resource "helm_release" "eks_main_metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server"
  chart            = "metrics-server"
  version          = "3.10.0"
  namespace        = "kube-system"
  create_namespace = false
  atomic           = true

  depends_on = [
    module.eks_main
  ]
}

# EKS - main - cluster-autoscaler
module "irsa_eks_main_cluster_autoscaler" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20.0"

  role_name = "eks-main-cluster-autoscaler-${var.environment}"

  attach_cluster_autoscaler_policy = true

  cluster_autoscaler_cluster_names = [module.eks_main.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_main.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler-aws-cluster-autoscaler"]
    }
  }

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

resource "helm_release" "eks_main_cluster_autoscaler" {
  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = "9.29.0"
  namespace        = "kube-system"
  create_namespace = false
  atomic           = true

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks_main.cluster_name
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_eks_main_cluster_autoscaler.iam_role_arn
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  depends_on = [
    module.eks_main, module.irsa_eks_main_cluster_autoscaler
  ]
}

# EKS - main - aws-load-balancer-controller
module "irsa_eks_main_aws_load_balancer_controller" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20.0"

  role_name = "eks-main-aws-load-balancer-controller-${var.environment}"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_main.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

resource "helm_release" "eks_main_aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "1.5.3"
  namespace        = "kube-system"
  create_namespace = false
  atomic           = true

  set {
    name  = "clusterName"
    value = module.eks_main.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_eks_main_aws_load_balancer_controller.iam_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc_main.vpc_id
  }

  depends_on = [
    module.eks_main, module.irsa_eks_main_aws_load_balancer_controller
  ]
}

# EKS - main - external-dns
module "irsa_eks_main_external_dns" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20.0"

  role_name = "eks-main-external-dns-${var.environment}"

  attach_external_dns_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_main.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

resource "helm_release" "eks_main_external-dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = "1.12.2"
  namespace        = "kube-system"
  create_namespace = false
  atomic           = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_eks_main_external_dns.iam_role_arn
  }

  set {
    name  = "aws.region"
    value = var.aws_region
  }

  depends_on = [
    module.eks_main, module.irsa_eks_main_external_dns
  ]
}

# EKS - main - cert-manager
module "irsa_eks_main_cert_manager" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20.0"

  role_name = "eks-main-cert-manager-${var.environment}"

  attach_cert_manager_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_main.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cert-manager"]
    }
  }

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

resource "helm_release" "eks_main_cert_manager" {
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  name             = "cert-manager"
  version          = "1.12.1"
  namespace        = "kube-system"
  create_namespace = false
  atomic           = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_eks_main_cert_manager.iam_role_arn
  }

  depends_on = [
    module.eks_main, module.irsa_eks_main_cert_manager
  ]
}

resource "kubectl_manifest" "eks_main_cert_manager_cluster_issuers" {
  count     = length(var.eks_main_cert_manager_cluster_issuers)
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${var.eks_main_cert_manager_cluster_issuers[count.index].name}
  namespace: cert-manager
spec:
  acme:
    server: ${var.eks_main_cert_manager_cluster_issuers[count.index].acme_server}
    email: ${var.eks_main_cert_manager_cluster_issuers[count.index].acme_email}
    privateKeySecretRef:
      name: ${var.eks_main_cert_manager_cluster_issuers[count.index].name}
    solvers:
    - selector:
        dnsZones:
          - "${var.public_domain}"
      dns01:
        route53:
          region: ${var.aws_region}
YAML

  depends_on = [helm_release.eks_main_cert_manager]
}

# EKS - main - container-insights
module "irsa_eks_main_container_insights" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20.0"

  role_name = "eks-main-container-insights-${var.environment}"

  role_policy_arns = {
    policy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_main.oidc_provider_arn
      namespace_service_accounts = ["kube-system:amazon-cloudwatch"]
    }
  }

  tags = {
    Terraform   = "true"
    Project     = var.project
    Environment = var.environment
  }
}

resource "helm_release" "eks_main_container_insights_aws_cloudwatch_metrics" {
  chart            = "aws-cloudwatch-metrics"
  repository       = "https://aws.github.io/eks-charts"
  name             = "aws-cloudwatch-metrics"
  version          = "0.0.9"
  namespace        = "kube-system"
  create_namespace = false
  atomic           = true

  set {
    name  = "serviceAccount.name"
    value = "amazon-cloudwatch"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_eks_main_container_insights.iam_role_arn
  }

  set {
    name  = "clusterName"
    value = module.eks_main.cluster_name
  }

  depends_on = [
    module.eks_main, module.irsa_eks_main_container_insights
  ]
}

resource "helm_release" "eks_main_container_insights_aws_for_fluent_bit" {
  chart            = "aws-for-fluent-bit"
  repository       = "https://aws.github.io/eks-charts"
  name             = "aws-for-fluent-bit"
  version          = "0.1.24"
  namespace        = "kube-system"
  create_namespace = false
  atomic           = true

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = "amazon-cloudwatch"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_eks_main_container_insights.iam_role_arn
  }

  set {
    name  = "cloudWatchLogs.region"
    value = var.aws_region
  }

  set {
    name  = "cloudWatchLogs.logGroupName"
    value = format("/aws/eks/%s/containerinsights/fluentbit", module.eks_main.cluster_name)
  }

  set {
    name  = "cloudWatchLogs.logGroupTemplate"
    value = format("/aws/eks/%s/containerinsights/fluentbit/workload/$kubernetes['namespace_name']", module.eks_main.cluster_name)
  }

  set {
    name  = "cloudWatchLogs.logRetentionDays"
    value = 30
  }

  depends_on = [
    module.eks_main, module.irsa_eks_main_container_insights, helm_release.eks_main_container_insights_aws_cloudwatch_metrics
  ]
}
