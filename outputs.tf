output "instance_ami" {
  value = aws_instance.blog.ami
}

output "instance_arn" {
  value = aws_instance.blog.arn
}

output "public_dns" {
  value = aws_public.blog.dns
}

output "public_ip" {
  value = aws_public.blog.ip
}