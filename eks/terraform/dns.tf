locals {
  domain = "${var.cluster_dns}.zeet.app"
}

resource "aws_route53_zone" "zeet" {
  name    = local.domain
  comment = "Managed by Zeet"
}
