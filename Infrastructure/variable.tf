variable "aws_vpc" {
  default  = "10.0.0.0/16"
  description = "My VPC"
}

variable "public_1_subnet_cidr" {
    description = "Public subnet 1 CIDR"
    default  = "10.0.0.0/20"
  
}

variable "public_2_subnet_cidr" {
    description = "Public subnet 1 CIDR"
    default  = "10.0.16.0/20"
  
}

variable "public_3_subnet_cidr" {
    description = "Public subnet 1 CIDR"
    default  = "10.0.32.0/20"
}

variable "private_1_subnet_cidr" {
    description = "Public subnet 1 CIDR"
    default  = "10.0.48.0/20"
}

variable "private_2_subnet_cidr" {
    description = "Public subnet 1 CIDR"
    default  = "10.0.64.0/20"
}

variable "private_3_subnet_cidr" {
    description = "Public subnet 1 CIDR"
    default  = "10.0.80.0/20"
}