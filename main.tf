resource "aws_eks_cluster" "test" {
  name     = "test-eks-cluster"
  role_arn = aws_iam_role.eks.arn
  version  = "1.36"

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.eks.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks]

}
