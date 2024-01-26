

resource "aws_iam_user" "external-dns" {
  name = "${var.project}-external-dns-${var.env}"
  path = "/"

  tags = {
    "Name"  = "external-dns"
    "Squad" = "Sec"
  }
}

resource "aws_iam_access_key" "external-dns" {
  user = aws_iam_user.external-dns.name
}


resource "aws_iam_user_policy" "external-dns" {
  name = "${var.project}-external-dns-${var.env}"
  user = aws_iam_user.external-dns.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": [
        "${aws_iam_role.external-dns.arn}"
      ]
    }
   ]
  }
EOF
}

resource "aws_iam_role" "external-dns" {
  name = "${var.project}-external-dns-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          "AWS" : "${aws_iam_user.external-dns.arn}"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "external-dns" {
  name        = "${var.project}-external-dns-${var.env}"
  path        = "/"
  description = "${var.project}-external-dns-${var.env}"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "route53:ChangeResourceRecordSets"
        ],
        Resource : [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        Effect : "Allow",
        Action : [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        Resource : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external-dns" {
  role       = aws_iam_role.external-dns.name
  policy_arn = aws_iam_policy.external-dns.arn
}

output "external-dns-iam-access-key" {
  value = aws_iam_access_key.external-dns.id
}

# Add password on AWS Secrets
resource "aws_secretsmanager_secret" "external-dns" {
  name        = "/${var.project}/${var.env}/external-dns"
  description = "Used by external-dns"
}

resource "aws_secretsmanager_secret_version" "external-dns" {
  secret_id     = aws_secretsmanager_secret.external-dns.id
  secret_string = jsonencode({ "AWS_ACCESS_KEY_ID" = "${aws_iam_access_key.external-dns.id}", "AWS_SECRET_ACCESS_KEY" = "${aws_iam_access_key.external-dns.secret}" })
  lifecycle {
    ignore_changes = [
      secret_string,
    ]
    #prevent_destroy = true
  }
}

resource "helm_release" "external-dns" {
  name             = "external-dns"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "external-dns"
  version          = "6.12.2"
  namespace        = "external-dns"
  create_namespace = true
  wait             = true

  set {
    name  = "aws.region"
    value = var.aws_region
  }

  set {
    name  = "aws.assumeRoleArn"
    value = aws_iam_role.external-dns.arn

  }

  set {
    name  = "aws.credentials.accessKey"
    value = aws_iam_access_key.external-dns.id
  }

  set {
    name  = "aws.credentials.secretKey"
    value = aws_iam_access_key.external-dns.secret
  }

  set {
    name  = "domainFilters[0]"
    value = local.subdomain
  }


  set {
    name  = "txtOwnerId"
    value = module.eks.cluster_name
  }

}

data "aws_autoscaling_groups" "eks" {
  filter {
    name   = "tag:eks:cluster-name"
    values = ["${module.eks.cluster_name}"]
  }
}





