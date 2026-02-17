variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_name" {
  type    = string
  default = "portfolio-blog-machine"
}

variable "eip_public_ip" {
  type    = string
  default = "52.6.232.178"
}

variable "attach_eip" {
  type    = bool
  default = true
}

# this to end up in terraform state if passed directly
variable "postgres_password" {
  type      = string
  sensitive = true
}
