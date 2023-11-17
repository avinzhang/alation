variable "aws_region" {
  type = string
  description = "AWS region to be used"
  default = "us-east-1"
}

variable "ec2_sshkey_name" {
  type = string
  default = "avin-tf-sshkey"
}

variable "ec2_public_key_path" {
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "ec2_instance_name" {
  type = string
}

variable "aws_role" {
  type = string
  description = "EC2 role for PS SSM"
  default = "PS_SSM_Sandbox"
}

variable "ec2_ingress_rules" {
  type = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_block  = string
    }))
  description = "EC2 ingress rules"
  default = [
  {
          from_port   = -1
          to_port     = -1
          protocol    = "icmp"
          cidr_block  = "0.0.0.0/0"
   },
  {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_block  = "0.0.0.0/0"
   },
  {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_block  = "0.0.0.0/0"
   }
   ]
}

variable "ec2_egress_rules" {
  type = list(object({
      from_port   = number
      to_port     = number
      protocol    = string
      cidr_block  = string
    }))
  description = "EC2 egress rules"
  default = [
  {
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_block  = "0.0.0.0/0"
   }
  ]
}


variable "vpc_id" {
  type = string
  default = "vpc-02236ae73cfeaeae9"
}
variable "subnet_id" {
  type = list
  default = ["subnet-025d2de2f15d9222f","subnet-0ae066ca1a1ecc6a8"]
}

variable "sg_ids" {
  type = list
  default = ["sg-0d95e18bd70a71910"]
}

variable "ec2_primary_count" {
  type = number
  default = 1
}

variable "volume_enabled" {
  type = bool
  default = false
}

variable "root_v_size" {
  type = number
  default = 60
}

variable "data_v_size" {
  type = number
  default = 80
}
variable "backup_v_size" {
  type = number
  default = 140
}

variable "aws_ssm_enabled" {
  type = bool
  default = true
}

variable "ec2_ami" {
  description = "centos 8  on us-east-1"
  type = string
  default = "ami-073d44ded6fa7b67c"
}

variable "ec2_type" {
  description = "Image type used"
  type = string
  default = "t2.medium"
}

variable "lb_enabled" {
  type = bool
  default = false
}

variable "lb_certificate_arn" {
  type = string
  default = "arn:aws:acm:us-east-1:255149284406:certificate/6654fc99-9129-4b93-9552-686b2f342bb2"
}

variable "zone_id_public" {
  type = string
  default = "ZIJ95C4PL1PB0"
}

variable "zone_id_private" {
  type = string
  default = "Z04856742LMOI8SDOTZTI"
}

variable "dns_name" {
  type = string
}

variable "install_alation" {
  type = bool
  default = false
}

variable "aws_key" {
  type = string
}

variable "aws_secret" {
  type = string
}

variable "owner" {
  type = string
}

variable "alation_email_username" {
  type = string
}
variable "alation_email_password" {
  type = string
}

variable "license_key_name" {
  type = string
  default = "ProServ_PRODUCTION_06-07-21.lic"
}

variable "alation_rpm_name" {
  type = string
  default = "alation-2023.3-17.0.0.49181.rpm"
}

variable "alation_firstuser_name" {
  type = string
}

variable "alation_firstuser_password" {
  type = string
}

variable "alation_rosemeta_db_password" {
  type = string
}

variable "alation_dnsname_prefix" {
  type = string
  default = "avin"
}
