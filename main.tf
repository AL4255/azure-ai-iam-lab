terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}


variable "subscription_id" {
  type = string
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-ai-lab"
  location = "centralus"
}


resource "azurerm_virtual_network" "lab" {
  name                = "vnet-ai-lab"
  address_space       = ["10.60.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_subnet" "lab" {
  name                 = "snet-ai-lab"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.60.1.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}


variable "admin_ip" {
  type        = string
  description = "My public IP, allowed to SSH"

  validation {
    condition     = can(cidrnetmask("${var.admin_ip}/32"))
    error_message = "admin_ip must be a valid IPv4 address, e.g 203.0.113.5."
  }
}

resource "azurerm_network_security_group" "lab" {
  name                = "nsg-ai-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "allow"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.admin_ip}/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "lab" {
  subnet_id                 = azurerm_subnet.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

resource "azurerm_public_ip" "lab" {
  name                = "pip-ai-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "lab" {
  name                = "nic-ai-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab.id

  }
}


resource "azurerm_user_assigned_identity" "agent" {
  name                = "id-ai-agent"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "lab" {
  name                     = "staillab${random_string.suffix.result}"
  location                 = azurerm_resource_group.lab.location
  resource_group_name      = azurerm_resource_group.lab.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"


  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false

  network_rules {
    default_action             = "Deny"
    ip_rules                   = [var.admin_ip]
    virtual_network_subnet_ids = [azurerm_subnet.lab.id]
  }

}

resource "azurerm_storage_container" "docs" {
  name                  = "docs"
  storage_account_id    = azurerm_storage_account.lab.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "secrets" {
  name                  = "secrets"
  storage_account_id    = azurerm_storage_account.lab.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "agent_read_docs" {
  scope                = azurerm_storage_container.docs.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.agent.principal_id
  principal_type       = "ServicePrincipal"
}
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "me_blob_contributor" {
  scope                = azurerm_storage_account.lab.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "log-ai-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
resource "azurerm_monitor_diagnostic_setting" "blob" {
  name                       = "blob-to-log-analytics"
  target_resource_id         = "${azurerm_storage_account.lab.id}/blobServices/defautl"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }
  enabled_log {
    category = "StorageDelete"
  }
}

resource "azurerm_linux_virtual_machine" "lab" {
  name                  = "vm-ai-lab"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = "Standard_B2s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.lab.id]
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    storage_account = azurerm_storage_account.lab.name
    client_id       = azurerm_user_assigned_identity.agent.client_id
  }))
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agent.id]
  }

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand("~/.ssh/ai_lab_ed25519.pub"))

  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "Ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "lab" {
  virtual_machine_id    = azurerm_linux_virtual_machine.lab.id
  location              = azurerm_resource_group.lab.location
  enabled               = true
  daily_recurrence_time = "2300"
  timezone              = "Central Standard Time"

  notification_settings {
    enabled = false
  }
}

