output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs das subnets de banco de dados"
  value       = aws_subnet.database[*].id
}

output "db_subnet_group_name" {
  description = "Nome do DB Subnet Group"
  value       = aws_db_subnet_group.this.name
}

output "nat_gateway_ips" {
  description = "IPs Elásticos dos NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "private_route_table_ids" {
  description = "IDs das route tables privadas (necessário para S3 Gateway Endpoint)"
  value       = aws_route_table.private[*].id
}

output "internet_gateway_id" {
  description = "ID do Internet Gateway"
  value       = aws_internet_gateway.this.id
}
