# Define the AWS AMI data source
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

# Define the default AWS VPC data source
data "aws_vpc" "default" {
  default = true
}

# Set up the VPC using the terraform-aws-modules/vpc/aws module
module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "dev-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Set up the security groups using the terraform-aws-modules/security-group/aws module
module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  name   = "blog_new"
  vpc_id = module.blog_vpc.vpc_id

  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

# Define a basic AWS security group
resource "aws_security_group" "blog" {
  name        = "blog"
  description = "Allow http and https in. Allow everything out"

  vpc_id = data.aws_vpc.default.id
}

# Set up the ALB using the terraform-aws-modules/alb/aws module
module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.0"
  name    = "blog-albs"

  vpc_id          = module.blog_vpc.vpc_id
  subnets         = module.blog_vpc.public_subnets
  security_groups = [module.blog_sg.security_group_id]

  target_groups = [
    {
      name_prefix      = "blog-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
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

  // Export the target group ARNs for use in other modules
  output "target_group_arns" {
    value = [for tg in aws_alb_target_group.main : tg.arn]
  }
}

# Define the launch template for the Auto Scaling Group
resource "aws_launch_template" "blog_template" {
  name          = "blog_template-launch-template"
  image_id      = data.aws_ami.app_ami.id
  instance_type = "t2.micro"  # Specify your desired instance type here

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [module.blog_sg.security_group_id]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Set up the Auto Scaling Group using the terraform-aws-modules/autoscaling/aws module
module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.6.1"
  name    = "blog"

  launch_template_id       = aws_launch_template.blog_template.id
  launch_template_version  = "$Latest"  # Use the latest version of the launch template

  min_size         = 1
  max_size         = 3
  desired_capacity = 2

  vpc_zone_identifier = module.blog_vpc.public_subnets
  target_group_arns   = module.blog_alb.target_group_arns  // Use target_group_arns from blog_alb module
}
