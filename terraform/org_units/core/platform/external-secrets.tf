resource "helm_release" "external-secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.9.11"
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true

  set {
    name  = "installCRDs"
    value = true
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.sa_external_secrets.iam_role_arn
  }

}

module "sa_external_secrets" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = " ~> 4.14"

  role_name                             = "${var.project}-external-secrets-${var.env}"
  create_role                           = true
  attach_external_secrets_policy        = true
  external_secrets_ssm_parameter_arns   = ["arn:aws:ssm:*:*:parameter/*"]
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:*:*:secret:*"]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

}
resource "kubectl_manifest" "secret_store_manager" {
  yaml_body = <<YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: ${var.project}-secrets-manager
      namespace: external-secrets
    spec:
      provider:
        aws:
          service: SecretsManager
          region: ${var.aws_region}
       YAML
  
  depends_on = [
    helm_release.external-secrets
  ]
}
