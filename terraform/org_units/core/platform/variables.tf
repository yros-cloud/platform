variable "project" {
  description = "Project Name"
  default     = "platform"
}

variable "env" {}
variable "organization_unit" {}
variable "network_prefix" {}
variable "domain_name" {}
variable "aws_region" {}
variable "is_shared" {}
variable "eks_instance_type" {}
variable "eks_node_disk_size" {}
variable "eks_enable_spot" {}
variable "eks_nodes_desired_size" {}
variable "eks_nodes_scale_min_size" {}
variable "eks_nodes_scale_max_size" {}
variable "infra_email_notification" {}

