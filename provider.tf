terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "myterraformvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my-vpc-terra-learn"
  }
}

resource "aws_subnet" "myterrsubnetpub" {
  vpc_id     = aws_vpc.myterraformvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "terr-public-sub"
  }
}

resource "aws_subnet" "myterrsubnetpri" {
  vpc_id     = aws_vpc.myterraformvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "terr-private-sub"
  }
}

resource "aws_internet_gateway" "myterrig" {
  vpc_id = aws_vpc.myterraformvpc.id

  tags = {
    Name = "MyTerrIG"
  }
}

resource "aws_route_table" "myterrpubroutetable" {
  vpc_id = aws_vpc.myterraformvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myterrig.id
  }

  tags = {
    Name = "my-pubRT"
  }
}

resource "aws_route_table_association" "publicsubnetassoication" {
  subnet_id      = aws_subnet.myterrsubnetpub.id
  route_table_id = aws_route_table.myterrpubroutetable.id
}

resource "aws_route_table" "myterrpriroutetable" {
  vpc_id = aws_vpc.myterraformvpc.id

  route {
    cidr_block = "0.0.0.0/0"  //those who can enter public subnet can enter private subnet too, so cidr 0.0.0.0/0
    gateway_id = aws_nat_gateway.terrng.id //befrore adding: to private subnet we need to connect with NAT, we connected it after creating in the bottom
  }

  tags = {
    Name = "my-priRT"
  }
}

resource "aws_route_table_association" "privatesubnetassoication" {
  subnet_id      = aws_subnet.myterrsubnetpri.id
  route_table_id = aws_route_table.myterrpriroutetable.id
}


resource "aws_security_group" "terrpubsg" {
  name        = "pubsg"
  description = "Allow ssh and http inbound traffic"
  vpc_id      = aws_vpc.myterraformvpc.id

  ingress { //to enabe ssh
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    //ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress { //to enabe http
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    //ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  //we are only modifying the inboound to egress removed

  tags = {
    Name = "terrpubsg"
  }
}

resource "aws_security_group" "terrprisg" {
  name        = "prisg"
  description = "Allow public sec inbound traffic"
  vpc_id      = aws_vpc.myterraformvpc.id

  ingress { //to enabe connecting public sg to pri sg
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.myterraformvpc.terrpubsg.cidr_blocks]
    //ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  //we are only modifying the inboound to egress removed

  tags = {
    Name = "terrprisg"
  }
}
resource "aws_eip" "terreip" {  //creating elastic ip for below nat gate
  #instance = aws_instance.web.id we are adding eip for nat gate so removed instance
  vpc      = true
}  


resource "aws_nat_gateway" "terrng" { //we need to natgate way to private route table
  allocation_id = aws_eip.terreip.id  //here we need elastic ip address
  subnet_id     = aws_subnet.myterrsubnetpub.id  //nat gate should always connected to public subnet

  tags = {
    Name = "terrng"
  }
}

//we have created the vpc above and below instance will reside inside that vpc
resource "aws_instance" "publicec2" {
  ami           = "ami-08e2d37b6a0129927"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = aws_subnet.myterrsubnetpub.id //when we mention the subnet it will auto choose the vpc
  vpc_security_group_ids = ["${aws_security_group.terrpubsg.id}"]

  tags = {
    Name = "publicec2"
  }
}

resource "aws_instance" "privatec2" {
  ami           = "ami-08e2d37b6a0129927"
  instance_type = "t2.micro"
  #associate_public_ip_address = true private don't need a public ip address
  subnet_id = aws_subnet.myterrsubnetpri.id //when we mention the subnet it will auto choose the vpc
  vpc_security_group_ids = ["${aws_security_group.terrprisg.id}"]

  tags = {
    Name = "privateec2"
  }
}
 
 