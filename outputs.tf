output "public_ip" {
  value       = azurerm_public_ip.lab.ip_address
  description = "Public IP of the lab VM, for SSH"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/ai_lab_ed25519 azureuser@${azurerm_public_ip.lab.ip_address}"
}

output "storage_account" {
  value = azurerm_storage_account.lab.name
}

output "agent-principal_id" {
  description = "The agent's object ID: this is RequesterObjectId in the logs"
  value       = azurerm_user_assigned_identity.agent.principal_id
}
