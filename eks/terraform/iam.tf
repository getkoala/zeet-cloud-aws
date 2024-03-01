module "iam_fluent-bit" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 3.0"

  create_role = true

  role_name = "${var.cluster_name}-fluent-bit"

  provider_url = module.eks.cluster_oidc_issuer_url

  role_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]
  number_of_role_policy_arns = 1

  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:fluent-bit"]
}

module "iam_cluster-autoscaler" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 3.0"

  create_role = true

  role_name = "${var.cluster_name}-cluster-autoscaler"

  provider_url = module.eks.cluster_oidc_issuer_url

  role_policy_arns = [
    aws_iam_policy.cluster-autoscaler.arn
  ]
  number_of_role_policy_arns = 1

  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:cluster-autoscaler"]
}

resource "aws_iam_policy" "cluster-autoscaler" {
  name = "${var.cluster_name}-cluster-autoscaler"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "ec2:DescribeLaunchTemplateVersions",
                "ec2:DescribeInstanceTypes",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "autoscaling:UpdateAutoScalingGroup"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

module "iam_cert-manager" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 3.0"

  create_role = true

  role_name = "${var.cluster_name}-cert-manager"

  provider_url = module.eks.cluster_oidc_issuer_url

  role_policy_arns = [
    aws_iam_policy.cert-manager.arn
  ]
  number_of_role_policy_arns = 1

  oidc_fully_qualified_subjects = ["system:serviceaccount:cert-manager:cert-manager"]
}

resource "aws_iam_policy" "cert-manager" {
  name = "${var.cluster_name}-cert-manager"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    }
  ]
}
EOF
}

module "iam_external-dns" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 3.0"

  create_role = true

  role_name = "${var.cluster_name}-external-dns"

  provider_url = module.eks.cluster_oidc_issuer_url

  role_policy_arns = [
    aws_iam_policy.external-dns.arn
  ]
  number_of_role_policy_arns = 1

  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:external-dns"]
}

resource "aws_iam_policy" "external-dns" {
  name = "${var.cluster_name}-external-dns"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/${aws_route53_zone.zeet.zone_id}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

