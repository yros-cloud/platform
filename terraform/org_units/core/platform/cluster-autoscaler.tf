resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.34.1"
  namespace  = "kube-system"
  wait       = true

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "autoscalingGroups[0].name"
    value = module.eks.eks_managed_node_groups_autoscaling_group_names[0]
  }

  set {
    name  = "autoscalingGroups[0].maxSize"
    value = var.eks_nodes_scale_max_size
  }

  set {
    name  = "autoscalingGroups[0].minSize"
    value = var.eks_nodes_scale_min_size
  }

  set {
    name  = "awsAccessKeyID"
    value = aws_iam_access_key.cluster_autoscaler.id
  }

  set {
    name  = "awsSecretAccessKey"
    value = aws_iam_access_key.cluster_autoscaler.secret
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

}

resource "aws_iam_user" "cluster_autoscaler" {
  name = "cluster-autoscaler"
  path = "/"

  tags = {
    "Name"  = "cluster-autoscaler"
    "Squad" = "Sec"
  }
}

resource "aws_iam_access_key" "cluster_autoscaler" {
  user = aws_iam_user.cluster_autoscaler.name
}

resource "aws_iam_user_policy" "cluster_autoscaler" {
  name = "cluster-autoscaler"
  user = aws_iam_user.cluster_autoscaler.name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeLaunchTemplateVersions",
                "ec2:DescribeInstanceTypes",
                "eks:DescribeNodegroup",
                "autoscaling:DescribeTags",
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF
}
