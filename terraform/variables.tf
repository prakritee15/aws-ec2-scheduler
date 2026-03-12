variable "project_name" { type = string  default = "ec2-scheduler" }
variable "aws_region"   { type = string  default = "ap-south-1" } # change if needed
variable "sns_email"    { type = string  default = "" }           # optional notification email
