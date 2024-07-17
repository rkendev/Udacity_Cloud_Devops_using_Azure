 # Define variables
$subscriptionId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # Replace with your actual subscription ID
$resourceGroupName = "myResourceGroup"
$location = "East US"
$imageName = "myPackerImage"
$ownerTag = "DevOps"
$environmentTag = "Development"
$storageAccountName = "mystorageaccountcrs1"
$containerName = "terraform-state"
$key = "terraform.tfstate"

# Step 1: Obtain Azure Service Principal Credentials

# Create Service Principal and store the output in a variable
$servicePrincipal = az ad sp create-for-rbac --name "packer-service-principal" --role Contributor --scopes "/subscriptions/$subscriptionId" | ConvertFrom-Json

# Extract the necessary details
$clientId = $servicePrincipal.appId
$clientSecret = $servicePrincipal.password
$tenantId = $servicePrincipal.tenant

# Output the Service Principal details
Write-Output "Service Principal created:"
Write-Output "Client ID: $clientId"
Write-Output "Client Secret: $clientSecret"
Write-Output "Tenant ID: $tenantId"

# Step 2: Set Environment Variables for Packer and Terraform
$env:ARM_CLIENT_ID = $clientId
$env:ARM_CLIENT_SECRET = $clientSecret
$env:ARM_SUBSCRIPTION_ID = $subscriptionId
$env:ARM_TENANT_ID = $tenantId
$env:RESOURCE_GROUP_NAME = $resourceGroupName
$env:LOCATION = $location
$env:IMAGE_NAME = $imageName
$env:OWNER_TAG = $ownerTag
$env:ENVIRONMENT_TAG = $environmentTag
$env:STORAGE_ACCOUNT_NAME = $storageAccountName
$env:CONTAINER_NAME = $containerName
$env:BACKEND_KEY = $key

Write-Output "Environment variables set for Packer and Terraform:"
Write-Output "ARM_CLIENT_ID: $env:ARM_CLIENT_ID"
Write-Output "ARM_CLIENT_SECRET: $env:ARM_CLIENT_SECRET"
Write-Output "ARM_SUBSCRIPTION_ID: $env:ARM_SUBSCRIPTION_ID"
Write-Output "ARM_TENANT_ID: $env:ARM_TENANT_ID"
Write-Output "RESOURCE_GROUP_NAME: $env:RESOURCE_GROUP_NAME"
Write-Output "LOCATION: $env:LOCATION"
Write-Output "IMAGE_NAME: $env:IMAGE_NAME"
Write-Output "OWNER_TAG: $env:OWNER_TAG"
Write-Output "ENVIRONMENT_TAG: $env:ENVIRONMENT_TAG"
Write-Output "STORAGE_ACCOUNT_NAME: $env:STORAGE_ACCOUNT_NAME"
Write-Output "CONTAINER_NAME: $env:CONTAINER_NAME"
Write-Output "BACKEND_KEY: $env:BACKEND_KEY"

# Step 3: Create Resource Group, Storage Account, and Container for Terraform State
$rgExists = az group show --name $resourceGroupName --query "properties.provisioningState" --output tsv 2>&1

if ($rgExists -eq "Succeeded") {
    Write-Output "Resource group $resourceGroupName already exists."
} else {
    Write-Output "Resource group $resourceGroupName does not exist. Creating it..."
    az group create --name $resourceGroupName --location $location --tags project=packer-deployment
    Write-Output "Resource group $resourceGroupName created."
}

# Create Storage Account if it doesn't exist
$storageAccountExists = az storage account check-name --name $storageAccountName --query "nameAvailable" | ConvertFrom-Json
if ($storageAccountExists -eq $true) {
    Write-Output "Storage account $storageAccountName does not exist. Creating it..."
    az storage account create --name $storageAccountName --resource-group $resourceGroupName --location $location --sku Standard_LRS --tags project=terraform-backend
    Write-Output "Storage account $storageAccountName created."
} else {
    Write-Output "Storage account $storageAccountName already exists."
}

# Get Storage Account Key
$storageAccountKey = az storage account keys list --resource-group $resourceGroupName --account-name $storageAccountName --query '[0].value' --output tsv

# Create Storage Container if it doesn't exist
$containerExists = az storage container exists --name $containerName --account-name $storageAccountName --account-key $storageAccountKey --query "exists" | ConvertFrom-Json
if ($containerExists -eq $false) {
    Write-Output "Storage container $containerName does not exist. Creating it..."
    az storage container create --name $containerName --account-name $storageAccountName --account-key $storageAccountKey
    Write-Output "Storage container $containerName created."
} else {
    Write-Output "Storage container $containerName already exists."
}

# Step 4: Create backend.tf file
$backendTfContent = @"
terraform {
  backend "azurerm" {
    resource_group_name  = "$resourceGroupName"
    storage_account_name = "$storageAccountName"
    container_name       = "$containerName"
    key                  = "$key"
  }
}
"@
Set-Content -Path "backend.tf" -Value $backendTfContent
Write-Output "backend.tf created with the following content:"
Write-Output $backendTfContent

# Step 5: Create terraform.tfvars file
$terraformTfvarsContent = @"
backend_resource_group_name = "$resourceGroupName"
backend_storage_account_name = "$storageAccountName"
backend_container_name = "$containerName"
backend_key = "$key"
"@
Set-Content -Path "terraform.tfvars" -Value $terraformTfvarsContent
Write-Output "terraform.tfvars created with the following content:"
Write-Output $terraformTfvarsContent

# Final Message
Write-Output "Setup completed. You can now proceed with running Packer and Terraform using these credentials and configurations."