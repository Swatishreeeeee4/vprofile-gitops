variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "EKS cluster name (also used as a name prefix and Project tag)"
  type        = string
  default     = "vprofile-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.37"
}

variable "node_instance_type" {
  description = "Worker node size (8 GB RAM fits the 5 app pods + Argo CD)"
  type        = string
  default     = "t3.large"
}
