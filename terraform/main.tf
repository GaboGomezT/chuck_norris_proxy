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
  name                 = "chuck-norris-proxy-v2"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "app" {
  name        = "chuck-norris-proxy-v2"
  description = "Chuck Norris Proxy API"
}

# IAM role for Elastic Beanstalk
resource "aws_iam_role" "eb_service" {
  name = "elastic_beanstalk_service_role_v2"

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
  name = "elastic_beanstalk_service_policy_v2"
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

# IAM role for EC2 instances
resource "aws_iam_role" "eb_ec2_role" {
  name = "aws-elasticbeanstalk-ec2-role-v2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "eb_ec2_profile" {
  name = "aws-elasticbeanstalk-ec2-profile-v2"
  role = aws_iam_role.eb_ec2_role.name
}

resource "aws_iam_role_policy_attachment" "eb_ec2_webtier" {
  role       = aws_iam_role.eb_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_ec2_ecr_readonly" {
  role       = aws_iam_role.eb_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eb_ec2_cloudwatch" {
  role       = aws_iam_role.eb_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "app" {
  name                = "chuck-norris-proxy-env-v2"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = var.solution_stack_name
  tier                = "WebServer"

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service.arn
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_ec2_profile.name
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

  depends_on = [
    aws_iam_instance_profile.eb_ec2_profile,
    aws_iam_role_policy_attachment.eb_ec2_webtier,
    aws_iam_role_policy_attachment.eb_ec2_ecr_readonly,
    aws_iam_role_policy_attachment.eb_ec2_cloudwatch
  ]
} 