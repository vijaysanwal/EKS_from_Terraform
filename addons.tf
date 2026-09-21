resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.test.name
  addon_name    = "vpc-cni"
  addon_version = "v1.23.1-eksbuild.1"

  depends_on = [
    aws_eks_node_group.nodes
  ]
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.test.name
  addon_name    = "coredns"
  addon_version = "v1.14.3-eksbuild.23"

  depends_on = [
    aws_eks_node_group.nodes
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.test.name
  addon_name    = "kube-proxy"
  addon_version = "v1.36.0-eksbuild.25"

  depends_on = [
    aws_eks_node_group.nodes
  ]
}
