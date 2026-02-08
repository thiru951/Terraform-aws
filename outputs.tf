output "eks_cluster_name" {
  value = aws_eks_cluster.thiru_eks.name
}

output "eks_endpoint" {
  value = aws_eks_cluster.thiru_eks.endpoint
}

