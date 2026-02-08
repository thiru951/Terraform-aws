terraform {
  required_version = "~> 1.5.0"

  backend "s3" {
    bucket         = "thiru-terraform-state-123"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# -------------------
# VPC
# -------------------
resource "aws_vpc" "thiru_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "thiru-vpc"
  }
}

resource "aws_subnet" "thiru_subnet" {
  vpc_id            = aws_vpc.thiru_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "thiru-subnet"
  }
}

# -------------------
# Security Group
# -------------------
resource "aws_security_group" "thiru_sg" {
  name   = "thiru-sg"
  vpc_id = aws_vpc.thiru_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------
# EKS IAM Role
# -------------------
resource "aws_iam_role" "eks_role" {
  name = "thiru-eks-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -------------------
# EKS Cluster
# -------------------
resource "aws_eks_cluster" "thiru_aks" {
  name     = "thiru-aks"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids         = [aws_subnet.thiru_subnet.id]
    security_group_ids = [aws_security_group.thiru_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_policy]
}

# -------------------
# Node Role
# -------------------
resource "aws_iam_role" "node_role" {
  name = "thiru-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy1" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_policy2" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# -------------------
# Node Group (2 nodes)
# -------------------
resource "aws_eks_node_group" "thiru_nodes" {
  cluster_name    = aws_eks_cluster.thiru_aks.name
  node_group_name = "thiru-node-group"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = [aws_subnet.thiru_subnet.id]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  instance_types = ["t3.medium"]
}

# -------------------
# EBS Storage 10GB
# -------------------
resource "aws_ebs_volume" "thiru_ebs" {
  availability_zone = "ap-south-1a"
  size              = 10

  tags = {
    Name = "thiru-storage-10gb"
  }
}

