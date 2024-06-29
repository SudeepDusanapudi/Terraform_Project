#creating a VPC
resource "aws_vpc" "TCS_VPC" {
  cidr_block = "10.0.0.0/16"
}

#Creating subnets
resource "aws_subnet" "public_sn_A" {
  vpc_id            = aws_vpc.TCS_VPC.id
  cidr_block        = "10.0.0.0/20"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Public_Subnet_A"
  }
}

resource "aws_subnet" "public_sn_B" {
  vpc_id            = aws_vpc.TCS_VPC.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Public_Subnet_B"
  }
}

#Internet_Gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.TCS_VPC.id
}

#Route table
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.TCS_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id

  }
}

#Route_table_association
resource "aws_route_table_association" "RTA1" {
  subnet_id      = aws_subnet.public_sn_A.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "RTA2" {
  subnet_id      = aws_subnet.public_sn_B.id
  route_table_id = aws_route_table.RT.id
}
#security groups
resource "aws_security_group" "websg" {
  name   = "web"
  vpc_id = aws_vpc.TCS_VPC.id

  ingress {
    description = "allow http"
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "webSG"

  }
}

#Ec2_instance
resource "aws_instance" "webserver1" {
  ami                         = "ami-0e001c9271cf7f3b9"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.websg.id]
  subnet_id                   = aws_subnet.public_sn_A.id
  user_data                   = base64encode(file("userdata.sh"))
  associate_public_ip_address = "true"
}

resource "aws_instance" "webserver2" {
  ami                         = "ami-0e001c9271cf7f3b9"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.websg.id]
  subnet_id                   = aws_subnet.public_sn_B.id
  user_data                   = base64encode(file("userdata1.sh"))
  associate_public_ip_address = "true"
}


#Load Balancer
resource "aws_lb" "ALB" {
  name               = "MyALB"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.websg.id]
  subnets         = [aws_subnet.public_sn_A.id, aws_subnet.public_sn_B.id]

  tags = {
    Name = "Web"
  }
}

#Target_Group:
resource "aws_lb_target_group" "TG" {
  name     = "MyTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.TCS_VPC.id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }
}

#Targetgroup_attachment
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.TG.id
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.TG.id
  target_id        = aws_instance.webserver2.id
  port             = 80

}

#Listner
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.ALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.TG.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.ALB.dns_name
}

