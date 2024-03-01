terraform {
  required_version = "~> 1.1.0"
}

provider "aws" {
  allowed_account_ids = [var.aws_account_id]
  region              = var.region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "aws_eip" "nat" {
  count = var.enable_nat ? 1 : 0
  vpc   = true
  tags = {
    ZeetClusterId = var.cluster_id
    ZeetUserId    = var.user_id
  }
}

data "aws_ami" "eks_gpu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-gpu-node-1.21*"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.0.0"

  name                 = var.cluster_name
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
  private_subnets      = ["10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19"]
  enable_dns_hostnames = true

  enable_nat_gateway  = var.enable_nat
  single_nat_gateway  = var.enable_nat
  reuse_nat_ips       = var.enable_nat
  external_nat_ip_ids = var.enable_nat ? aws_eip.nat[*].id : []

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  tags = {
    ZeetClusterId = var.cluster_id
    ZeetUserId    = var.user_id
  }
}

resource "aws_security_group" "worker_public" {
  name_prefix = "worker_public"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    from_port = 1024
    to_port   = 65535
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    from_port = 1024
    to_port   = 65535
    protocol  = "udp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  autoscaler_common = [
    {
      "key"                 = "k8s.io/cluster-autoscaler/enabled"
      "propagate_at_launch" = "false"
      "value"               = "true"
    },
    {
      "key"                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
      "propagate_at_launch" = "false"
      "value"               = "true"
    },
    {
      "key"                 = "k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage"
      "propagate_at_launch" = "false"
      "value"               = "100Gi"
    }
  ]
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = "ssh_key_${var.cluster_id}"
  public_key = tls_private_key.ssh.public_key_openssh
}


locals {
  worker_templates_cpu = [
    {
      name          = "c5-4xlarge-dedicated"
      instance_type = "c5.4xlarge"

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=dedicated",
        "--register-with-taints zeet.co/dedicated=dedicated:NoSchedule"
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "dedicated"
        },
      ])
    },
    {
      name          = "c5-2xlarge-dedicated"
      instance_type = "c5.2xlarge"

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=dedicated",
        "--register-with-taints zeet.co/dedicated=dedicated:NoSchedule"
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "dedicated"
        },
      ])
    },
    {
      name          = "c5-xlarge-dedicated"
      instance_type = "c5.xlarge"

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=dedicated",
        "--register-with-taints zeet.co/dedicated=dedicated:NoSchedule"
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "dedicated"
        },
      ])
    },
    {
      name          = "m5-large-dedicated"
      instance_type = "m5.large"

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=dedicated",
        "--register-with-taints zeet.co/dedicated=dedicated:NoSchedule"
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "dedicated"
        },
      ])
    },
    {
      name                    = "c5-xlarge-guaranteed-spot"
      override_instance_types = ["c5.xlarge"]
      spot_instance_pools     = 10

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=guaranteed,node.kubernetes.io/lifecycle=spot",
        "--register-with-taints zeet.co/dedicated=guaranteed:NoSchedule"
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "guaranteed"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/lifecycle"
          "propagate_at_launch" = "false"
          "value"               = "spot"
        }
      ])
    },
    {
      name                 = "m5-large-system"
      instance_type        = "m5.large"
      asg_desired_capacity = 1

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=system",
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "system"
        }
      ])
    },
    {
      name          = "m5-large-shared"
      instance_type = "m5.large"

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=shared,node.kubernetes.io/lifecycle=spot",
        "--register-with-taints zeet.co/dedicated=shared:NoSchedule",
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "shared"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/lifecycle"
          "propagate_at_launch" = "false"
          "value"               = "spot"
        }
      ])
    },
    {
      name          = "m5-large-dedicated-private"
      instance_type = "m5.large"

      public_ip = false
      subnets   = [sort(module.vpc.private_subnets)[0]]

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=dedicated,zeet.co/static-ip=true",
        "--register-with-taints zeet.co/dedicated=dedicated:NoSchedule,zeet.co/static-ip=true:NoSchedule"
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "dedicated"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/static-ip"
          "propagate_at_launch" = "false"
          "value"               = "true"
        },
      ])
    },
    {
      name                    = "c5-xlarge-guaranteed-private-spot"
      override_instance_types = ["c5.xlarge"]
      spot_instance_pools     = 10

      public_ip = false
      subnets   = [sort(module.vpc.private_subnets)[0]]

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=guaranteed,zeet.co/static-ip=true,node.kubernetes.io/lifecycle=spot",
        "--register-with-taints zeet.co/dedicated=guaranteed:NoSchedule,zeet.co/static-ip=true:NoSchedule"
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "guaranteed"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/lifecycle"
          "propagate_at_launch" = "false"
          "value"               = "spot"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/static-ip"
          "propagate_at_launch" = "false"
          "value"               = "true"
        },
      ])
    },
  ]

  worker_templates_gpu = [
    {
      name          = "g4dn-xlarge-dedicated"
      instance_type = "g4dn.xlarge"
      ami_id        = data.aws_ami.eks_gpu.id

      kubelet_extra_args = join(" ", [
        "--node-labels=zeet.co/dedicated=dedicated,zeet.co/gpu=\"true\"",
        "--register-with-taints nvidia.com/gpu=present:NoSchedule",
      ])

      tags = concat(local.autoscaler_common, [
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/dedicated"
          "propagate_at_launch" = "false"
          "value"               = "dedicated"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/node-template/label/zeet.co/gpu"
          "propagate_at_launch" = "false"
          "value"               = "true"
        },
      ]),
    }
  ]

  worker_templates = var.enable_gpu ? concat(worker_templates_cpu, worker_templates_gpu) : worker_templates_cpu
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.1.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.21"
  subnets         = flatten([module.vpc.private_subnets, module.vpc.public_subnets])

  tags = {
    ZeetClusterId = var.cluster_id
    ZeetUserId    = var.user_id
  }

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_id = module.vpc.vpc_id

  worker_groups_launch_template = [for template in local.worker_templates :
    merge({
      key_name             = aws_key_pair.ssh.key_name
      asg_desired_capacity = 0
      asg_min_size         = 0
      asg_max_size         = 10

      public_ip                     = true
      subnets                       = [sort(module.vpc.public_subnets)[0]]
      additional_security_group_ids = [aws_security_group.worker_public.id]
    }, template)
  ]
}

data "tls_certificate" "eks" {
  url = module.eks.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates.0.sha1_fingerprint]
  url             = module.eks.cluster_oidc_issuer_url
}

resource "aws_ecr_repository" "zeet" {
  name                 = "zeet/${var.cluster_id}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    ZeetClusterId = var.cluster_id
    ZeetUserId    = var.user_id
  }
}
