variable "config_file" {
  description = "config_file."
  type        = list(string)
  default     = ["/home/nanda/.aws/config"]
}

variable "creds_file" {
  description = "creds_file."
  type        = list(string)
  default     = ["/home/nanda/.aws/credentials"]
}

variable "aws_profile" {
  description = "this is aws profile"
  type        = string
  default     = "grit-cloudnanda"
}

variable "aws_region" {
  description = "this is aws region to provision your infrasture with terraform"
  type        = string
  default     = "ap-southeast-1"
}

variable "email_address" {
  description = "this is your email address"
  type        = string
  default     = "devopsnandahein28@gmail.com"
}

variable "stage_name" {
  description = "this is your stage name"
  type        = string
  default     = "dev"
}