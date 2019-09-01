data "aws_region" "current" {} #A

resource "aws_resourcegroups_group" "resourcegroups_group" {
  name = "${var.namespace}-group"

  resource_query { #B
    query = <<-JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "ResourceGroup",
      "Values": ["${var.namespace}"]
    }
  ]
}
  JSON
  }
}

resource "random_string" "rand" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_kms_key" "kms_key" {
  tags = {
    ResourceGroup = var.namespace 
  }
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${var.namespace}-state-bucket-${random_string.rand.result}"

  versioning {
    enabled = true
  }
  force_destroy = var.force_destroy_state
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.kms_key.arn
      }
    }
  }
  tags = {
    ResourceGroup = var.namespace 
  }
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name         = "${var.namespace}-state-lock"
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST" #C
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    ResourceGroup = var.namespace 
  }
}
#A This will be used to set an output value
#B Populate the resource group based on a tagging schema
#C Provision a serverless database to save money
Next is the code for iam.tf. This particular code is important because it creates a least priviliged IAM role that another AWS account can assume in order to be able to leverage the S3 remote backend for state storage. It grants IAM permissions for storing the state file in S3, and getting/deleting records in the DynamoDB table for locking purposes.
