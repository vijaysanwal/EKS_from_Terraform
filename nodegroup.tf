resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.test.name
  node_group_name = "test-node-group"

  node_role_arn = aws_iam_role.eks_nodes.arn

  subnet_ids     = aws_subnet.private[*].id
  version        = "1.36"
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_worker,
    aws_iam_role_policy_attachment.eks_nodes_cni,
    aws_iam_role_policy_attachment.eks_nodes_ecr
  ]

  tags = {
    Name = "test-eks-node"
  }
}
