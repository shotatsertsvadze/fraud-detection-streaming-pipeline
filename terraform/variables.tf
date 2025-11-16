
variable "project" {
  default = "fraud-pipeline"
}

variable "env" {
  default = "dev"
}

variable "aws_region" {
  default = "eu-central-1"
}

locals {
  name_prefix = "${var.project}-${var.env}"
}
