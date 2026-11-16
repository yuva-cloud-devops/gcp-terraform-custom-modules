output "vpc_summary" {
  value = module.networking.vpcs
}

output "subnet_summary" {
  value = module.networking.subnets
}

output "router_summary" {
  value = module.networking.routers
}

output "nat_summary" {
  value = module.networking.nat_gateways
}

output "firewall_summary" {
  value = module.networking.firewall_rules
}

output "private_service_access_ranges" {
  value = module.networking.private_service_access_ranges
}

output "private_service_access_connections" {
  value = module.networking.private_service_access_connections
}
