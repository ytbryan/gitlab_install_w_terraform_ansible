output "public_ip" {
  value = azurerm_public_ip.main.ip_address
}

output "private_ip" {
  value = azurerm_network_interface.main.private_ip_address
}

output "fqdn" {
  value = azurerm_public_ip.main.fqdn
}