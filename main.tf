# configured aws provider with proper credentials
provider "aws" {
  region  = "eu-west-2"
  profile = "default"
}


# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {

  tags = {
    Name = "default vpc"
  }
}


# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}


# create default subnet if one does not exit
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet"
  }
}


# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 8080 and 22"
  vpc_id      = aws_default_vpc.default_vpc.id

  # open port on security group - allow access on port 8080
  ingress {
    description = "http proxy access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # should be limited in production setup
  }

  # allow access on port 22
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # should be limited in production setup
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins server security group"
  }
}


# launch the ec2 instance and install jenkins
resource "aws_instance" "jenkins_ec2_instance" {
  ami                    = "ami-0acc77abdfc7ed5a6"
  instance_type          = "t2.micro"
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "ec2-key"
  # user_data            = file("install_jenkins.sh")

  tags = {
    Name = "Jenkins Server - EC2"
  }
}


# an empty resource block to ssh into ec2 instance and run install-jenkins script
resource "null_resource" "name" {

  # ssh into the jenkins ec2 instance 
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/ec2-key.pem")
    host        = aws_instance.jenkins_ec2_instance.public_ip
  }

  # copy the install_jenkins.sh file from your computer to the ec2 instance 
  provisioner "file" {
    source      = "install-jenkins.sh"
    destination = "/tmp/install-jenkins.sh"
  }

  provisioner "file" {
    source      = "install-ansible.sh"
    destination = "/tmp/install-ansible.sh"
  }

  provisioner "file" {
    source      = "install-terraform.sh"
    destination = "/tmp/install-terraform.sh"
  }

  provisioner "file" {
    source      = "install-git.sh"
    destination = "/tmp/install-git.sh"
  }

  # set permissions and runs install scripts
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install-jenkins.sh",
      "sudo chmod +x /tmp/install-terraform.sh",
      "sudo chmod +x /tmp/install-ansible.sh",
      "sudo chmod +x /tmp/install-git.sh",

      "sh /tmp/install-terraform.sh",
      "sh /tmp/install-ansible.sh",
      "sh /tmp/install-git.sh",
      "sh /tmp/install-jenkins.sh"
    ]
  }

  # wait for jenkins ec2 instance to be created
  depends_on = [aws_instance.jenkins_ec2_instance]
}


# print the url of the jenkins server
output "website_url" {
  value = join("", ["http://", aws_instance.jenkins_ec2_instance.public_dns, ":", "8080"])
}
