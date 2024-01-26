resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"

  chart      = "argo-cd"
  version    = "5.53.8"
  namespace = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value =  "LoadBalancer"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-backend-protocol"
    value =  "https"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
    value =  aws_acm_certificate.platform.arn
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-ports"
    value = "https"
  }

  set {
    name  = "server.service.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = "argocd.${local.subdomain}"
  }


  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.iam_role.arn
  }

  set {
    name  = "server.config.url"
    value = "https://argocd.${local.subdomain}"
  }

  set {
    name  = "server.config.kustomize\\.path\\.default"
    value = "/usr/local/bin/kustomize"
  }

  set {
    name  = "server.env[0].name"
    value = "ARGOCD_AUTH_TOKEN"
  }

  set {
    name  = "accounts.admin.enabled"
    value = "true"
  }

  set {
    name  = "accounts.crossplane"
    value = "apiKey"
  }


  set {
    name  = "accounts.crossplane.enabled"
    value = "true"
  }

  set {
    name  = "server.env[0].value"
    value = random_password.admin_token.result
  }


  set {
    name  = "server.env[0].value"
    value = random_password.admin_token.result
  }

  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = htpasswd_password.hash.bcrypt
  }

  set {
    name  = "configs.credentialTemplates.ssh-creds.url"
    value = "git@github.com:yros-cloud"
  }


  set {
    name  = "redis.enabled"
    value = false
  }

}

resource "random_password" "password" {
  length = 30
}

resource "random_password" "admin_token" {
  length = 30
  special          = false
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "salt" {
  length = 8
}

resource "htpasswd_password" "hash" {
  password = random_password.password.result
  salt     = random_password.salt.result
}


# Add passwords on AWS Secrets
resource "aws_secretsmanager_secret" "argocd" {
  name = "/${var.project}/${var.env}/argocd"
  description = "${var.project} ArgoCD login ${var.env}"
}

resource "aws_secretsmanager_secret_version" "argocd" {
  secret_id = aws_secretsmanager_secret.argocd.id
  secret_string = jsonencode({
    "login" = "admin",
    "password" = random_password.password.result
    "admin_token" = random_password.admin_token.result
  })

}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:argocd:argocd-*"]
    }

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.id}:oidc-provider/${module.eks.oidc_provider}"]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "iam_role" {
  name                  = "${var.project}-argocd-${var.env}"
  assume_role_policy    = data.aws_iam_policy_document.assume_role_policy.json
  force_detach_policies = true
}


resource "aws_iam_policy" "argocd" {
  name = "${var.project}-argocd-${var.env}"
  path        = "/"
  description = "argocd policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.id}:role/${aws_iam_role.iam_role.name}"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "argocd" {
  name       = "${var.project}-argocd-${var.env}"
  roles      = [aws_iam_role.iam_role.name]
  policy_arn = aws_iam_policy.argocd.arn
}
