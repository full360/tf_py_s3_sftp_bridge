###################################################################################################

terraform {
  required_version = ">= 0.11.0"
}

###################################################################################################

variable "integration_name" {}

variable "integration_bucket" {
  type = "map"
}

variable "function_prefix" {
  default = "s3-sftp-bridge"
}

variable "service_tag" {}
###################################################################################################

variable "ssh_key_path" {}
variable "ssh_key_file" {}
variable "ssh_host_key_path" {}
variable "ssh_host_key_file" {}
variable "security_groups" { default = [] }
variable "subnets" { default = [] }

###################################################################################################

# variable "lambda_function_package_path" {}

variable "lambda_description" {
  default = "Managed by Terraform"
}

###################################################################################################

variable "sftp_host" {}
variable "sftp_user" {}
variable "sftp_location" {}

variable "sftp_port" {
  default = "22"
}

###################################################################################################

variable "retry_schedule_expression" {
  default = "cron(0/5 * * * ? *)"
}

variable "retry_scheduled_event_description" {
  default = "Managed by Terraform"
}

###################################################################################################
