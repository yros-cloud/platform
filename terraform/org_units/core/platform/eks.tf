## EKS

module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "19.21.0"
  cluster_name                    = "${var.project}-${var.env}"
  cluster_version                 = "1.29"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  aws_auth_roles = ["arn:aws:iam::851725436574:role/AWSReservedSSO_AdministratorAccess_31b79bd8a666cc38"]

  cluster_addons = {
    kube-proxy = {}
  }

  create_kms_key            = false

  cluster_encryption_config = {}
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
    instance_type                          = var.eks_instance_type
    update_launch_template_default_version = true
    iam_role_additional_policies           = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project}-alb-ingress-${var.env}", 
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project}-external-secrets-${var.env}", 
      "AmazonEBSCSIDriverPolicy"
    ]
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    disk_size              = var.eks_node_disk_size
    instance_types         = [        
        "t3.medium",
        "t3.large",
        "t3a.small",
        "t3a.medium",
        "t3a.large",
        "t2.small",
        "t2.medium",
        "t2.large"]
    vpc_security_group_ids = [aws_security_group.additional.id]
  }


  # Extend node-to-node security group rules
  node_security_group_additional_rules = {

    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      cidr_blocks                   = ["0.0.0.0/0"]
      ipv6_cidr_blocks              = ["::/0"]
    }

    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

  }

  eks_managed_node_groups = {
    platform-node = {
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "optional"
        http_put_response_hop_limit = 2
      }
      min_size     = var.eks_nodes_scale_min_size
      max_size     = var.eks_nodes_scale_max_size
      desired_size = var.eks_nodes_desired_size

      instance_types = [
        var.eks_instance_type
      ]
      capacity_type = "SPOT"
      instance_types = [
        "t3.medium",
        "t3.large",
        "t3a.small",
        "t3a.medium",
        "t3a.large",
        "t2.small",
        "t2.medium",
        "t2.large",
      ]
      labels = {
        managed-by  = "terraform"
        environment = "${var.env}"
        OU          = var.organization_unit
      }
      tags = {
        managed-by  = "terraform"
        environment = "${var.env}"
        OU          = var.organization_unit
      }

    }
  }
}

resource "aws_kms_key" "eks" {
  description             = "${var.project} ${var.env} EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  #tags = ""
}

resource "aws_kms_key" "ebs" {
  description             = "${var.project}-${var.env} Customer managed key to encrypt EKS managed node group volumes"
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.ebs.json
}

# This policy is required for the KMS key used for EKS root volumes, so the cluster is allowed to enc/dec/attach encrypted EBS volumes
data "aws_iam_policy_document" "ebs" {
  # Copy of default KMS policy that lets you manage it
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  # Required for EKS
  statement {
    sid = "Allow service-linked role use of the CMK"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks.cluster_iam_role_arn,                                                                                                            # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }
  }
  statement {
    sid       = "Allow attachment of persistent resources"
    actions   = ["kms:CreateGrant"]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks.cluster_iam_role_arn,                                                                                                            # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

}

resource "aws_security_group" "additional" {
  name        = "eks-additional-sg"
  description = "eks-additional-sg"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "eks-additional-sg"
  }
}

output "cluster_id" {
  value = module.eks.cluster_id
}

output "workers_asg_names" {
  value = module.eks.self_managed_node_groups
}
