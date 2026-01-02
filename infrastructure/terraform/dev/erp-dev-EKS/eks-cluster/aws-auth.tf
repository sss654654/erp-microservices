data "aws_iam_role" "codebuild" {
  name = "erp-dev-codebuild-role"
}

data "aws_iam_role" "eks_node" {
  name = "erp-dev-eks-node-role"
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = data.aws_iam_role.eks_node.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      },
      {
        rolearn  = data.aws_iam_role.codebuild.arn
        username = "codebuild"
        groups = [
          "system:masters"
        ]
      }
    ])
  }

  force = true

  depends_on = [aws_eks_cluster.main]
}
