module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.8.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  subnet_ids      = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
  vpc_id          = aws_vpc.main.id

  enable_irsa     = true
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true


  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      subnet_ids     = aws_subnet.private[*].id
    }
  }

  tags = {
    Environment = "sre-lab"
  }
}

