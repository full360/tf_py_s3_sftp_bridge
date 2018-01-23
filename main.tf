data "aws_caller_identity" "current" {}

module "py_s3_sftp_bridge" {
  source = "github.com/full360/py-s3-sftp-bridge?ref=6d5fde48"
}

###############################################################################

resource "aws_lambda_function" "s3_sftp_bridge_lambda" {

  filename         = "${pathexpand(module.py_s3_sftp_bridge.lambda_zip)}"
  function_name    = "${var.service_tag}-${var.function_prefix}-${var.integration_name}"
  description      = "${var.lambda_description}"
  runtime          = "python2.7"
  role             = "${aws_iam_role.lambda_role.arn}"
  handler          = "s3_sftp_bridge.handler"
  source_code_hash = "${base64sha256(file(pathexpand(module.py_s3_sftp_bridge.lambda_zip)))}"

  timeout          = 300

  dead_letter_config {
    target_arn = "${aws_sqs_queue.dead_letter.arn}"
  }

  vpc_config {
    security_group_ids = "${var.security_groups}"
    subnet_ids  = "${var.subnets}"
  }

  environment {
    variables = {
      QUEUE_NAME      = "${aws_sqs_queue.dead_letter.name}"
      SFTP_HOST       = "${var.sftp_host}"
      SFTP_PORT       = "${var.sftp_port}"
      SFTP_USER       = "${var.sftp_user}"
      SFTP_LOCATION   = "${var.sftp_location}"
      SFTP_S3_SSH_KEY = "${var.service_tag}-${var.function_prefix}-ssh-keys-${var.integration_name}/${var.ssh_key_file}"
      SFTP_S3_SSH_HOST_KEY= "${var.service_tag}-${var.function_prefix}-ssh-keys-${var.integration_name}/${var.ssh_host_key_file}"
    }
  }

  lifecycle {
    ignore_changes = ["source_code_hash"]
  }

  depends_on = ["module.py_s3_sftp_bridge"]

}

###############################################################################


###############################################################################

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.s3_sftp_bridge_lambda.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${var.integration_bucket["arn"]}"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${var.integration_bucket["id"]}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.s3_sftp_bridge_lambda.arn}"
    events              = ["s3:ObjectCreated:*"]
  }
}

###############################################################################

###############################################################################

resource "aws_iam_role" "lambda_role" {
  name = "${var.service_tag}-${var.function_prefix}-${var.integration_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  role = "${aws_iam_role.lambda_role.id}"
  name = "s3_access"

  policy = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Sid"     :   "1",
      "Effect"  :   "Allow",
      "Action"  : [ "s3:CopyObject",
                    "s3:GetObject",
                    "s3:ListObjects",
                    "s3:PutObject" ],
      "Resource": [ "arn:aws:s3:::${var.integration_bucket["id"]}",
                    "arn:aws:s3:::${var.integration_bucket["id"]}/*",
                    "arn:aws:s3:::${var.service_tag}-${var.function_prefix}-ssh-keys-${var.integration_name}",
                    "arn:aws:s3:::${var.service_tag}-${var.function_prefix}-ssh-keys-${var.integration_name}/*" ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_ec2" {
  role = "${aws_iam_role.lambda_role.id}"
  name = "ec2_networkinterfaces"

  policy = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Sid"     :   "1",
      "Effect"  :   "Allow",
      "Action"  :   ["ec2:CreateNetworkInterface",
                     "ec2:DescribeNetworkInterfaces",
                     "ec2:DetachNetworkInterface",
                     "ec2:DeleteNetworkInterface"],
      "Resource":   "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_logging" {
  role = "${aws_iam_role.lambda_role.id}"
  name = "logging"

  policy = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Sid"     :   "1",
      "Effect"  :   "Allow",
      "Action"  : [ "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents" ],
      "Resource":   "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_kms" {
  role = "${aws_iam_role.lambda_role.id}"
  name = "kms"

  policy = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Sid"     :   "1",
      "Effect"  :   "Allow",
      "Action"  :   "kms:Decrypt",
      "Resource":   "${aws_kms_key.configuration_key.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_dead_letter_sqs" {
  role = "${aws_iam_role.lambda_role.id}"
  name = "sqs"

  policy = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Sid"     :   "1",
      "Effect"  :   "Allow",
      "Action"  : [ "sqs:GetQueueUrl",
                    "sqs:ReceiveMessage",
                    "sqs:SendMessage",
                    "sqs:DeleteMessage" ],
      "Resource":   "${aws_sqs_queue.dead_letter.arn}"
    }
  ]
}
EOF
}

###############################################################################

###############################################################################

resource "aws_kms_key" "configuration_key" {
  description = "${var.service_tag}-${var.function_prefix}-${var.integration_name}"
}

resource "aws_kms_alias" "configuration_key" {
  name          = "alias/${var.service_tag}-${var.function_prefix}-${var.integration_name}"
  target_key_id = "${aws_kms_key.configuration_key.key_id}"
}

###############################################################################


###############################################################################


resource "aws_lambda_permission" "allow_scheduled_event" {
  statement_id  = "AllowExecutionFromScheduledEvent"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.s3_sftp_bridge_lambda.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.trigger_retry.arn}"
}

resource "aws_cloudwatch_event_rule" "trigger_retry" {
  name                = "${var.service_tag}-${var.function_prefix}-${var.integration_name}"
  description         = "${var.retry_scheduled_event_description}"
  schedule_expression = "${var.retry_schedule_expression}"
}

resource "aws_cloudwatch_event_target" "s3_sftp_bridge_lambda" {
  rule      = "${aws_cloudwatch_event_rule.trigger_retry.name}"
  arn       = "${aws_lambda_function.s3_sftp_bridge_lambda.arn}"
  target_id = "${var.service_tag}-${var.function_prefix}"
}

###############################################################################



###############################################################################


resource "aws_sqs_queue" "dead_letter" {
  name                      = "${var.service_tag}-${var.function_prefix}${var.function_prefix}-${var.integration_name}"
  message_retention_seconds = 1209600
}

###############################################################################


###############################################################################


variable "s3_keys_versioning" {
  default = "true"
}

###############################################################################


resource "aws_s3_bucket" "ssh_keys" {
  bucket = "${var.service_tag}-${var.function_prefix}-ssh-keys-${var.integration_name}"

  policy = <<EOF
{
  "Version":"2012-10-17",
  "Id":"PutObjPolicy",
  "Statement":[
    {
      "Sid": "DenyIncorrectEncryptionHeader",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${var.service_tag}-${var.function_prefix}-ssh-keys-${var.integration_name}/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    }
  ]
}
EOF

  versioning {
    enabled = "${var.s3_keys_versioning}"
  }

  tags {
    Name = "${var.service_tag}-${var.function_prefix}-ssh-keys-${var.integration_name}"
  }
}

###############################################################################


resource "aws_s3_bucket_object" "ssh_key" {
  key        = "${var.ssh_key_file}"
  bucket     = "${aws_s3_bucket.ssh_keys.id}"
  source     = "${var.ssh_key_path}/${var.ssh_key_file}"
  kms_key_id = "${aws_kms_key.configuration_key.arn}"
}

resource "aws_s3_bucket_object" "ssh_host_key" {
  key        = "${var.ssh_host_key_file}"
  bucket     = "${aws_s3_bucket.ssh_keys.id}"
  source     = "${var.ssh_host_key_path}/${var.ssh_host_key_file}"
  kms_key_id = "${aws_kms_key.configuration_key.arn}"
}
###############################################################################
