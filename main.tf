data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a","us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24","10.0.102.0/24","10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"
  name    = "blog_new"

  vpc_id               = module.blog_vpc.vpc_id
  ingress_rules        = ["http-80-tcp","https-443-tcp"]
  ingress_cidr_blocks  = ["0.0.0.0/0"]

  egress_rules         = ["all-all"]
  egress_cidr_blocks   = ["0.0.0.0/0"]
}

resource "aws_security_group" "blog" {
  name        = "blog"
  description = "Allow http and https in. Allow everything out"

  vpc_id = data.aws_vpc.default.id
}

module "autoscaling_example_complete" {
  source  = "terraform-aws-modules/autoscaling/aws//examples/complete"
  version = "7.6.1"

  name = "blog-alb"
  default_autoscaling_group_min_size = 1
  default_autoscaling_group_max_size = 2 

  default_autoscaling_group_vpc_zone_identifier = module.blog_vpc.public_subnets
  default_autoscaling_group_target_group_arns = module.blog_alb.target_group_arns
  vpc_id                                      = module.blog_vpc.vpc_id

}

module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.0"
  name    = "blog-alb"

  vpc_id                      = module.blog_vpc.vpc_id
  subnets                     = module.blog_vpc.public_subnets
  security_groups             = [module.blog_sg.security_group_id]
  associate_public_ip_address = true
  
  image_id         = data.aws_ami.app_ami.id
  instance_type    = var.instance_type
  
  target_groups = [
    {
      name_prefix      = "blog-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      targets = {
        my_target = {
          target_id = aws_instance.blog.id
          port      = 80
        }
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "Dev"
  }
}


  