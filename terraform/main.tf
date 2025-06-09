terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = "chuck-norris-proxy"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "app" {
  name        = "chuck-norris-proxy"
  description = "Chuck Norris Proxy API"
}

# IAM role for Elastic Beanstalk
resource "aws_iam_role" "eb_service" {
  name = "elastic_beanstalk_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticbeanstalk.amazonaws.com"
        }
      }
    ]
  })
}

# IAM role policy for Elastic Beanstalk
resource "aws_iam_role_policy" "eb_service" {
  name = "elastic_beanstalk_service_policy"
  role = aws_iam_role.eb_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "elasticbeanstalk:*",
          "ec2:*",
          "ecs:*",
          "ecr:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "s3:*",
          "sns:*",
          "cloudformation:*",
          "rds:*",
          "logs:*",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "app" {
  name                = "chuck-norris-proxy-env"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = var.solution_stack_name
  tier                = "WebServer"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_role.eb_service.name
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "InstanceTypes"
    value     = "t2.micro"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PORT"
    value     = "4000"
  }


} 