provider "aws" {
    region = "us-east-1"
}

data "aws_security_group" "sg_estudos" {
  filter {
    name   = "group-name"
    values = ["grupo_sg_estudos"]
  }
}

resource "aws_instance" "SigaBox" {
    ami                         =   "ami-0f9de6e2d2f067fca"
    instance_type               =   "t3.small"
    key_name                    =   "projeto_siga"
    vpc_security_group_ids      = [data.aws_security_group.sg_estudos.id]
    tags = {
        Name = "SigaBox"
    }
  provisioner "remote-exec" {
    inline = ["sudo apt update -y"]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("/home/ubuntu/projeto-siga/projeto_siga.pem")
      host        = self.public_ip
    }
  }
  provisioner "local-exec" {
    command = <<EOT
    echo "[Projeto-siga]
    ${self.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=projeto_siga.pem" > hosts.ini
    ssh-keyscan -H ${self.public_ip} >> /home/ubuntu/.ssh/known_hosts
EOT
  }
}

output "public_ip" {
  value = aws_instance.SigaBox.public_ip
}