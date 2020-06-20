terraform {
  required_version = ">= 0.12"
}

# ---------------------------------------------------------------------------------------------------------------------
# Create policy document allowing EC2 instances to assume the role this document is attached to.
# Provider Docs: https://www.terraform.io/docs/providers/aws/d/iam_policy_document.html
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Create IAM role to be assumed by EC2 instances
# Provider Docs: https://www.terraform.io/docs/providers/aws/r/iam_role.html
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.ec2.json
}

# ---------------------------------------------------------------------------------------------------------------------
# Fetch the current AWS account (needed for constructing db-connect ARN)
# Provider Docs: https://www.terraform.io/docs/providers/aws/d/caller_identity.html
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# Fetch the curret AWS region (needed for constructing db-connect ARN)
# Provider Docs: https://www.terraform.io/docs/providers/aws/d/region.html
# ---------------------------------------------------------------------------------------------------------------------
data "aws_region" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# Local variable to store shorthand region and account
# Docs: https://www.terraform.io/docs/configuration/locals.html
# ---------------------------------------------------------------------------------------------------------------------
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ---------------------------------------------------------------------------------------------------------------------
# Create IAM policy document defining permissions for role once assumed
# Provider Docs: https://www.terraform.io/docs/providers/aws/d/iam_policy_document.html
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "db" {
  statement {
    actions = ["rds-db:connect"]
    effect  = "Allow"
    resources = [
      "arn:aws:rds-db:${local.region}:${local.account_id}:dbuser:${var.db_resource_id}/db-user-name"
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Create IAM policy from document to be attached to role
# Provider Docs: https://www.terraform.io/docs/providers/aws/r/iam_policy.html
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "db" {
  policy = data.aws_iam_policy_document.db.json
}

# ---------------------------------------------------------------------------------------------------------------------
# Attach policy to role
# Provider Docs: https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.db.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# Create instance profile for role
# Provider Docs: https://www.terraform.io/docs/providers/aws/r/iam_instance_profile.html
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_instance_profile" "this" {
  role = aws_iam_role.this.name
}

