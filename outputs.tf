output "public_ip" {
  value       = azurerm_public_ip.lab.ip_address
  description = "Public IP of the lab VM, for SSH"
}
