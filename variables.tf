variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t3.nano"
}

variable "launch_template_id" {
  description = "The ID of the launch template"
  type        = "lt-0d9e653067a573618string"
}
