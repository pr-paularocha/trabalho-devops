resource "aws_vpc" "default" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc-${terraform.workspace}"
  }
}

resource "aws_subnet" "public" {
  depends_on = [
    aws_vpc.default
  ]
  vpc_id                                      = aws_vpc.default.id
  cidr_block                                  = "10.0.1.0/24"
  availability_zone                           = var.availability_zone
  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true

  tags = {
    Name = "public-${terraform.workspace}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "igw-${terraform.workspace}"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rt-${terraform.workspace}"
  }
}

resource "aws_route_table_association" "subnet-public" {
  depends_on = [
    aws_internet_gateway.igw,
    aws_route_table.rt
  ]
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "principal-sg" {
  name        = "principal-${terraform.workspace}"
  description = "Acesso HTTP e SSH"
  vpc_id      = aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "principal-sg-${terraform.workspace}"
  }
}

resource "aws_ebs_volume" "principal_volume" {
  availability_zone    = var.availability_zone
  size                 = 4
  type                 = var.volume_type
  iops                 = 200
  multi_attach_enabled = true

  tags = {
    Name = "principal-volume-${terraform.workspace}"
  }
}

resource "aws_instance" "principal_instance" {
  depends_on = [
    aws_ebs_volume.principal_volume
  ]
  count             = var.instances_count
  ami               = "ami-0568773882d492fc8" #Amazon Linux 2
  instance_type     = "t3.micro"
  subnet_id         = aws_subnet.public.id
  security_groups   = [aws_security_group.principal-sg.id]
  availability_zone = var.availability_zone
  user_data         = <<EOF
    #!/bin/bash 
    # Install Nginx
    sudo amazon-linux-extras install nginx1 -y
    sudo chkconfig nginx on
    sudo systemctl start nginx
    EOF

  tags = {
    Name = "principal-instance-${terraform.workspace}-${count.index + 1}"
  }
}

resource "aws_volume_attachment" "principal_volume_attached" {
  depends_on = [
    aws_ebs_volume.principal_volume
  ]
  count       = var.instances_count
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.principal_volume.id
  instance_id = element(aws_instance.principal_instance.*.id, ((count.index + 1) % 2))
}