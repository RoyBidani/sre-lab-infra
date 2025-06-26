resource "aws_key_pair" "sre_lab_key" {
  key_name   = "sre-lab-key"
  public_key = file("~/.ssh/EnvKey.pub")
}

resource "aws_security_group" "admin_sg" {
  name        = "admin-sg"
  description = "Allow SSH and web ports"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Admin-SG"
  }
}

resource "aws_instance" "admin_node" {
  ami                         = "ami-04e601abe3e1a910f" # Ubuntu 22.04 (eu-central-1)
  instance_type               = "t3.micro"
  subnet_id                  = aws_subnet.public[0].id
  key_name                   = aws_key_pair.sre_lab_key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids     = [aws_security_group.admin_sg.id]

  tags = {
    Name = "SRE-Lab-Admin-Node"
  }
}
