output "vpc_id" {
    value = "${aws_vpc.production_vpc.id}"
}

output "vpc_cidr_block" {
    value = "${aws_vpc.production_vpc.cidr_block}"
}

output "public_1_subnet_cidr" {
    value = "${aws_subnet.public-subnet-1.id}"
}

output "public_2_subnet_cidr" {
    value = "${aws_subnet.public-subnet-2.id}"
}

output "public_3_subnet_cidr" {
    value = "${aws_subnet.public-subnet-3.id}"
}

output "private_1_subnet_cidr" {
    value = "${aws_subnet.public-subnet-1.id}"
}

output "private_2_subnet_cidr" {
    value = "${aws_subnet.public-subnet-2.id}"
}

output "private_3_subnet_cidr" {
    value = "${aws_subnet.public-subnet-3.id}"
}

output "ecs_public_subnets" {
  value = [
    aws_subnet.public-subnet-1.id,
    aws_subnet.public-subnet-2.id,
    aws_subnet.public-subnet-3.id
  ]
}