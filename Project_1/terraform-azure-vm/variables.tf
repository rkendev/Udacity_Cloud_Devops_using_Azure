# Azure subscription ID
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}

# Resource Group Name
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "myResourceGroup"
}

# Azure region
variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"  # Ensure it matches the correct value
}

# Tags to apply to resources
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    Environment = "Development"
    Owner       = "DevOps"
  }
}

# Size of the virtual machine
variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B1s"
}

# Admin username for the virtual machine
variable "admin_username" {
  description = "Admin username for the virtual machine"
  type        = string
  default     = "azureuser"
}

# Name of the managed image to use for the VM
variable "image_name" {
  description = "Name of the managed image to use for the VM"
  type        = string
  default     = "myPackerImage"
}

# Resource Group of the managed image to use for the VM
variable "image_resource_group_name" {
  description = "Resource Group of the managed image to use for the VM"
  type        = string
  default     = "myResourceGroup"
}

# Number of virtual machines to deploy
variable "vm_count" {
  description = "Number of virtual machines to deploy (min 2, max 5)"
  type        = number
  default     = 2
  validation {
    condition = var.vm_count >= 2 && var.vm_count <= 5
    error_message = "The vm_count must be between 2 and 5."
  }
}

# Load balancer SKU
variable "lb_sku" {
  description = "SKU for the Load Balancer"
  type        = string
  default     = "Standard"
}

# Frontend port for the Load Balancer
variable "frontend_port" {
  description = "Frontend port for the Load Balancer"
  type        = number
  default     = 80
}

# Backend port for the Load Balancer
variable "backend_port" {
  description = "Backend port for the Load Balancer"
  type        = number
  default     = 80
}

# Protocol for the Load Balancer
variable "lb_protocol" {
  description = "Protocol for the Load Balancer"
  type        = string
  default     = "Tcp"
}

# Backend configuration variables
variable "backend_resource_group_name" {
  description = "The name of the resource group for the backend"
  type        = string
  default     = "myResourceGroup"  # Added default value
}

variable "backend_storage_account_name" {
  description = "The name of the storage account for the backend"
  type        = string
  default     = "mystorageaccountcrs1"  # Added default value
}

variable "backend_container_name" {
  description = "The name of the storage container for the backend"
  type        = string
  default     = "terraform-state"  # Added default value
}

variable "backend_key" {
  description = "The name of the key for the backend state file"
  type        = string
  default     = "terraform.tfstate"  # Added default value
}

# Declare the vm_name variable to resolve the undeclared variable error
variable "vm_name" {
  description = "The name of the VM"
  type        = string
  default     = "myVM"  # Set a sensible default value if applicable
}
