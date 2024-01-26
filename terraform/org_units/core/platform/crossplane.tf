resource "helm_release" "crossplane" {
  name       = "crossplane"
  repository = "https://charts.crossplane.io/stable"

  chart      = "crossplane"
  version    = "1.14.0"
  namespace = "crossplane-system"
  create_namespace = true

  set {
    name  = "args"
    value =  "{--enable-composition-revisions}"
  }

}

data "aws_iam_policy_document" "crossplane_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${module.eks.oidc_provider_arn}:sub"
      values   = ["system:serviceaccount:crossplane-system:*"]
    }

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.id}:oidc-provider/${module.eks.oidc_provider_arn}"]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" crossplane_iam_role {
  name                  = "crossplane"
  assume_role_policy    = data.aws_iam_policy_document.assume_role_policy.json
  force_detach_policies = true
}

resource "aws_iam_role_policy" "crossplane" {
  name = "${var.project}-crossplane-${var.env}"
  role = aws_iam_role.crossplane_iam_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


# AWS PROVIDER

resource "kubectl_manifest" "cross-plane-aws-provider" {
  yaml_body = <<YAML
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-aws
    spec:
      package: xpkg.upbound.io/crossplane-contrib/provider-aws:v0.39.0
  YAML
  depends_on = [
    helm_release.crossplane
  ]
}

# HELM PROVIDER

resource "kubectl_manifest" "cross-plane-helm-provider" {
  yaml_body = <<YAML
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-helm
    spec:
      package: "crossplanecontrib/provider-helm:master"
  YAML
  depends_on = [
    helm_release.crossplane
  ]
}

## ARGOCD PROVIDER


resource "kubectl_manifest" "argocd-crossplane-provider" {
  yaml_body = <<YAML
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-argocd
    spec:
      package: xpkg.upbound.io/crossplane-contrib/provider-argocd:v0.2.0
  YAML
  depends_on = [
    helm_release.crossplane
  ]  
}

resource "kubectl_manifest" "argocd-crossplane-provider-config" {
  yaml_body = <<YAML
    apiVersion: argocd.crossplane.io/v1alpha1
    kind: ProviderConfig
    metadata:
      name: argocd-provider
    spec:
      serverAddr: argocd.dev.yros.cloud:443
      insecure: true
      plainText: false
      credentials:
        source: Secret
        secretRef:
          namespace: crossplane-system
          name: argocd-crossplane-token
          key: admin_token
  YAML
  depends_on = [
    helm_release.crossplane,
    kubectl_manifest.argocd-crossplane-provider
  ]  
}

resource "kubectl_manifest" "cross-plane-argocd-controller-conf" {
  yaml_body = <<YAML
    apiVersion: pkg.crossplane.io/v1alpha1
    kind: ControllerConfig
    metadata:
      name: argocd-conf
      namespace: "crossplane-system"
    spec:
     args:
     - '--debug'
  YAML
  depends_on = [
    helm_release.crossplane
  ]  
}


/*
resource "kubectl_manifest" "cross-plane-aws-controller-conf" {
  yaml_body = <<YAML
    apiVersion: pkg.crossplane.io/v1alpha1
    kind: ControllerConfig
    metadata:
      name: aws-config
      namespace: "crossplane-system"
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.crossplane_iam_role.arn}"
    spec:
      podSecurityContext:
        fsGroup: 2000
      args:
      - '--debug'
  YAML
  depends_on = [
    helm_release.crossplane
  ]
}

resource "kubectl_manifest" "cross-plane-controller-debug-conf" {
  yaml_body = <<YAML
    apiVersion: pkg.crossplane.io/v1alpha1
    kind: ControllerConfig
    metadata:
      name: debug-config
      namespace: "crossplane-system"
    spec:
      args:
      - '--debug'
  YAML
  depends_on = [
    helm_release.crossplane
  ]
}



resource "kubectl_manifest" "cross-plane-aws-provider-conf" {
  yaml_body = <<YAML
    apiVersion: aws.crossplane.io/v1beta1
    kind: ProviderConfig
    metadata:
      name: default
      namespace: "crossplane-system"
    spec:
      credentials:
        source: InjectedIdentity
  YAML
  depends_on = [
    helm_release.crossplane
  ]  
}

resource "kubectl_manifest" "cross-plane-kubernetes-provider-conf" {
  yaml_body = <<YAML
    apiVersion: kubernetes.crossplane.io/v1alpha1
    kind: ProviderConfig
    metadata:
      name: default
      namespace: "crossplane-system"
    spec:
      credentials:
        source: InjectedIdentity
  YAML
  depends_on = [
    helm_release.crossplane
  ]  
}


resource "kubectl_manifest" "cross-plane-aws-provider" {
  yaml_body = <<YAML
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: aws-provider
      namespace: "crossplane-system"
    spec:
      ignoreCrossplaneConstraints: false
      package: crossplane/provider-aws:v0.46.0
      packagePullPolicy: IfNotPresent
      revisionActivationPolicy: Automatic
      revisionHistoryLimit: 1
      skipDependencyResolution: false
  YAML
  depends_on = [
    helm_release.crossplane
  ]  
}


*/

