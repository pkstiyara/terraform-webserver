provider "aws" {
    region = "us-east-1"
    # access_key = "" DO not use
    # secret_key = "" Do not use
  
}


# resource "aws_instance" "my-server" {
#     ami = "ami-08c40ec9ead489470"
#     instance_type = "t2.micro"

#     tags = {
#         Name = "Ubuntu-Web-Server"
#     }
# }

# resource "aws_vpc" "demo-terr-vpc" {
#     cidr_block = "10.0.0.0/16"
    
#     tags = {
#         Name = "prodcution"

#     }
# }

# resource "aws_subnet" "subnet-1" {
#     vpc_id = aws_vpc.demo-terr-vpc.id
#     cidr_block = "10.0.1.0/24"

#     tags = {
#       Name = "prod-subnet"
#     }
  
# }

# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Launching a Web Server with Terraform 
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.0.0.0/16"
  

  tags = {
    Name = "prod-vpc"
  }
}

# Create Internet Gateway


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "prod-ig"
  }
}

# Create Custom Route Table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# Create a Subnet

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"

    tags = {
      Name = "prod-subnet"
    }
}
# Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create a Securtiy Group and allow port 22 80 and 443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow-web"
  }
}
# Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.0.50"]
  security_groups = [aws_security_group.allow_web.id]

  
}
# Assign and elstic IP to the network interface that was created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.0.50"
  depends_on = [aws_internet_gateway.gw]
    
}
# Create an ubntu server and install/enable apche2 server

resource "aws_instance" "web-server-instance" {
    ami = "ami-08c40ec9ead489470"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "aws-key-test"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web-server-nic.id
    }

    user_data = <<-EOF
                #!bin/bash
                sudo apt-get update && sudo apt-get upgrade -y
                sudo apt install apache2 -y
                sudo systemctl enable apache2
                EOF
    
    tags = {
      Name = "Web-Server"
    }
  
}

output "server_public_ip" {
    value = aws_eip.one.public_ip
  
}

