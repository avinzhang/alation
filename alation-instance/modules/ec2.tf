resource "aws_instance" "primary" {
  count = var.ec2_primary_count
  ami = var.ec2_ami
  instance_type = var.ec2_type
  key_name = var.ec2_sshkey_name
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.e2_profile.name
  subnet_id = element(var.subnet_id, count.index)
  vpc_security_group_ids = concat(var.sg_ids,[aws_security_group.ec2_security_groups.id])
  root_block_device {
    volume_size = var.root_v_size 
    volume_type = "gp2"
  }

  tags = {
    Owner = var.owner
    Name = "${var.ec2_instance_name}-${count.index}"
  }
}

resource "aws_ebs_volume" "primary_ebs_data" {
  count = var.volume_enabled ? 1 : 0
  availability_zone = aws_instance.primary[count.index].availability_zone
  size              = var.data_v_size
  tags = {
    Name = "${var.ec2_instance_name}-primary-data-${count.index}"
    Owner = var.owner
  }
}

resource "aws_ebs_volume" "primary_ebs_backup" {
  count = var.volume_enabled ? 1 : 0
  availability_zone = aws_instance.primary[count.index].availability_zone
  size              = var.backup_v_size
  tags = {
    Name = "${var.ec2_instance_name}-primary-backup-${count.index}"
    Owner = var.owner
  }
}

resource "aws_volume_attachment" "primary_ebs_att_data" {
  count = var.volume_enabled ? 1 : 0
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.primary_ebs_data[count.index].id
  instance_id = aws_instance.primary[count.index].id
}

resource "aws_volume_attachment" "primary_ebs_att_backup" {
  count = var.volume_enabled ? 1 : 0
  device_name = "/dev/sde"
  volume_id   = aws_ebs_volume.primary_ebs_backup[count.index].id
  instance_id = aws_instance.primary[count.index].id
}

resource "null_resource" "install_ssm_agent" {
  count = var.aws_ssm_enabled ? 1 : 0
  connection {
      type  = "ssh"
      user  = "centos"
      private_key  = file("~/.ssh/id_rsa")
      host  = aws_instance.primary[count.index].public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm",
      "sudo systemctl enable amazon-ssm-agent",
      "sudo systemctl start amazon-ssm-agent",
    ]
  }
}


resource "null_resource" "server_setup" {
  count = var.volume_enabled ? 1 : 0
  connection {
      type  = "ssh"
      user  = "centos"
      private_key  = file("~/.ssh/id_rsa")
      host  = aws_instance.primary[count.index].public_ip
  }
  triggers = {
    file = "${sha256(file("../modules/server_setup.sh"))}"
  }
  provisioner "file" {
    source = "../modules/server_setup.sh"
    destination = "/tmp/server_setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/server_setup.sh",
      "/tmp/server_setup.sh"
    ]
  }

  depends_on  = [aws_volume_attachment.primary_ebs_att_data,
       aws_volume_attachment.primary_ebs_att_backup]
}

resource "null_resource" "install_alation" {
  count = var.install_alation ? 1 : 0
  connection {
      type  = "ssh"
      user  = "centos"
      private_key  = file("~/.ssh/id_rsa")
      host  = aws_instance.primary[count.index].public_ip
  }
  triggers = {
    file = "${sha256(file("../modules/install_alation.sh.tpl"))}"
  }
  provisioner "file" {
    destination = "/tmp/install_alation.sh"

    content = templatefile(
    "../modules/install_alation.sh.tpl",
    {
      aws_key="${var.aws_key}",
      aws_secret="${var.aws_secret}",
      alation_rpm_name="${var.alation_rpm_name}",
      license_key_name="${var.license_key_name}",
      alation_email_username="${var.alation_email_username}",
      alation_email_password="${var.alation_email_password}",
      alation_rosemeta_db_password="${var.alation_rosemeta_db_password}",
      alation_firstuser_name="${var.alation_firstuser_name}",
      alation_firstuser_password="${var.alation_firstuser_password}",
      alation_dnsname_prefix="${var.alation_dnsname_prefix}"
     }
    )
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_alation.sh",
      "/tmp/install_alation.sh",
      "sudo rm /tmp/install_alation.sh"
    ]
  }

  depends_on  = [aws_volume_attachment.primary_ebs_att_data,
       aws_volume_attachment.primary_ebs_att_backup]
}
