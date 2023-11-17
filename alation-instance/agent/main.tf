variable "aws_key" {}
variable "aws_secret" {}
variable "alation_rosemeta_db_password" {}
variable "alation_email_username" {}
variable "alation_firstuser_password" {}
variable "alation_email_password" {}

module "agent" {
  source = "../modules/"
  ec2_instance_name = "avin-agent"
  owner = "avin.zhang"
  aws_key = var.aws_key
  alation_rosemeta_db_password = var.alation_rosemeta_db_password
  alation_email_username = ""
  alation_firstuser_name = ""
  alation_firstuser_password = var.alation_firstuser_password
  alation_email_password = var.alation_email_password
  aws_secret = var.aws_secret
  ec2_sshkey_name = "avin-tf-sshkey"
  dns_name = "avin.alationproserv.com"

}
