terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.57.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Data source to check if the resource group exists
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Data source to check if the image exists
data "azurerm_image" "existing_image" {
  name                = var.image_name
  resource_group_name = var.image_resource_group_name
}

# Local values to conditionally reference resources
locals {
  rg_exists           = length(data.azurerm_resource_group.main.id) > 0
  rg_location         = local.rg_exists ? data.azurerm_resource_group.main.location : var.location
  rg_name             = local.rg_exists ? data.azurerm_resource_group.main.name : var.resource_group_name
  storage_account_name = var.backend_storage_account_name
  image_exists        = length(data.azurerm_image.existing_image.id) > 0
  image_id            = data.azurerm_image.existing_image.id
}

# Resource Group
resource "azurerm_resource_group" "main" {
  count    = local.rg_exists ? 0 : 1
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# Create a Storage Account for Terraform state
resource "azurerm_storage_account" "terraform_storage_account" {
  count                = local.rg_exists ? 0 : 1
  name                 = local.storage_account_name
  resource_group_name  = var.resource_group_name
  location             = var.location
  account_tier         = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

# Create a Storage Container for Terraform state
resource "azurerm_storage_container" "terraform" {
  count               = local.rg_exists ? 0 : 1
  name                = var.backend_container_name
  storage_account_name = local.storage_account_name
  container_access_type = "private"
}

# Managed Image
resource "azurerm_image" "packer_image" {
  count               = local.image_exists ? 0 : 1
  name                = var.image_name
  resource_group_name = var.image_resource_group_name
  location            = var.location
  hyper_v_generation  = "V1"
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "myVNet"
  address_space       = ["10.0.0.0/16"]
  location            = local.rg_location
  resource_group_name = local.rg_name

  tags = var.tags
}

# Subnet
resource "azurerm_subnet" "main" {
  name                 = "mySubnet"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "myNSG"
  location            = local.rg_location
  resource_group_name = local.rg_name

  tags = var.tags

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Explicit deny rule for all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP traffic from the load balancer to the VMs
  security_rule {
    name                       = "AllowLoadBalancerHTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "lb" {
  name                = "lb-public-ip"
  location            = local.rg_location
  resource_group_name = local.rg_name
  allocation_method   = "Dynamic"

  tags = var.tags
}

# Public IPs for VMs
resource "azurerm_public_ip" "vm_ips" {
  count               = var.vm_count
  name                = "vm-public-ip-${count.index}"
  location            = local.rg_location
  resource_group_name = local.rg_name
  allocation_method   = "Dynamic"

  tags = var.tags
}

# Network Interface
resource "azurerm_network_interface" "main" {
  count               = var.vm_count
  name                = "packer-nic-${count.index}"
  location            = local.rg_location
  resource_group_name = local.rg_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_ips[count.index].id
  }

  tags = var.tags
}

# Network Interface Security Group Association
resource "azurerm_network_interface_security_group_association" "main" {
  count                       = var.vm_count
  network_interface_id        = element(azurerm_network_interface.main.*.id, count.index)
  network_security_group_id   = azurerm_network_security_group.main.id
}

# Load Balancer
resource "azurerm_lb" "main" {
  name                = "myLoadBalancer"
  location            = local.rg_location
  resource_group_name = local.rg_name

  frontend_ip_configuration {
    name                 = "myFrontEndConfig"
    public_ip_address_id = azurerm_public_ip.lb.id
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "main" {
  name            = "myBackEndPool"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_lb_nat_rule" "main" {
  name                        = "myNatRule"
  loadbalancer_id             = azurerm_lb.main.id
  protocol                    = "Tcp"
  frontend_port               = 80
  backend_port                = 80
  frontend_ip_configuration_name = azurerm_lb.main.frontend_ip_configuration[0].name
  resource_group_name         = local.rg_name
}

resource "azurerm_lb_probe" "main" {
  name                = "httpProbe"
  loadbalancer_id     = azurerm_lb.main.id
  protocol            = "Http"
  request_path        = "/"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
  resource_group_name = local.rg_name
}

# Null resource to create SSH key pair and set permissions
resource "null_resource" "create_ssh_key" {
  provisioner "local-exec" {
    command = <<EOT
      powershell -Command "Remove-Item -Force './id_rsa','./id_rsa.pub'; ssh-keygen -t rsa -b 4096 -f './id_rsa' -N ''; $acl = Get-Acl './id_rsa'; $permission = '\$($env:USERNAME)','FullControl','Allow'; $acl.SetAccessRuleProtection(\$true, \$false); $acl.Access | ForEach-Object { \$acl.RemoveAccessRule(\$_) }; \$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule \$permission)); Set-Acl './id_rsa' \$acl"
    EOT
  }
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  count                 = var.vm_count
  name                  = "myVM-${count.index}"
  location              = local.rg_location
  resource_group_name   = local.rg_name
  size                  = var.vm_size
  network_interface_ids = [element(azurerm_network_interface.main.*.id, count.index)]
  admin_username        = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("./id_rsa.pub")  # Ensure this path is correct for your setup
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Correctly reference the existing image
  source_image_id = local.image_id

  tags = var.tags

  depends_on = [null_resource.create_ssh_key]
}
