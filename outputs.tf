output "public_ip" {
  value       = azurerm_public_ip.lab.ip_address
  description = "Public IP of the lab VM, for SSH"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/ai_lab_ed25519 azureuser@{azurerm_public_ip.lab.ip_address}"
}
