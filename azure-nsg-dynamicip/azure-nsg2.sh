#!/bin/bash

# Check Azure CLI authentication
az account show > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: You must log in to Azure first using 'az login'."
  exit 1
fi

# Variables (accept as parameters)
subscription_id="${1:-<YOUR_SUBSCRIPTION_ID>}"
resource_group="${2:-<YOUR_RESOURCE_GROUP>}"
nsg_name="${3:-<YOUR_NSG_NAME>}"
nsg_rule_name="${4:-<YOUR_NSG_RULE_NAME>}"
location="${5:-<YOUR_LOCATION>}"  # Location for creating the NSG if it doesn't exist
destination_port_ranges="${6:-22}"  # Dynamically passed port range, defaults to 22 (SSH) if not provided

# Fetch current public IP
public_ip=$(curl -s https://api.ipify.org)
if [ -z "$public_ip" ]; then
  echo "Error: Failed to fetch public IP. Check your internet connection."
  exit 1
fi
echo "Your current public IP: $public_ip"

# Check if the NSG exists
nsg=$(az network nsg show --resource-group $resource_group --name $nsg_name --subscription $subscription_id --query id --output tsv)

if [ -z "$nsg" ]; then
  # Create the NSG if it does not exist
  echo "NSG '$nsg_name' not found. Creating a new NSG..."
  az network nsg create --resource-group $resource_group --name $nsg_name --location $location --subscription $subscription_id

  if [ $? -ne 0 ]; then
    echo "Error: Failed to create NSG."
    exit 1
  fi

  echo "NSG created with name: $nsg_name"
else
  echo "Using existing NSG: $nsg_name"
fi

# Check if the NSG rule exists
nsg_rule=$(az network nsg rule show --resource-group $resource_group --nsg-name $nsg_name --name $nsg_rule_name --subscription $subscription_id --query id --output tsv)

if [ -n "$nsg_rule" ]; then
  # Revoke the old NSG rule
  echo "Deleting old NSG rule: $nsg_rule_name..."
  az network nsg rule delete --resource-group $resource_group --nsg-name $nsg_name --name $nsg_rule_name --subscription $subscription_id
fi

# Create/Update the NSG rule with the new public IP and dynamic port range
echo "Creating NSG rule with new public IP: $public_ip/32 and port range: $destination_port_ranges"
az network nsg rule create \
  --resource-group $resource_group \
  --nsg-name $nsg_name \
  --name $nsg_rule_name \
  --priority 1000 \
  --source-address-prefixes "$public_ip/32" \
  --destination-port-ranges $destination_port_ranges \
  --access Allow \
  --protocol Tcp \
  --direction Inbound \
  --subscription $subscription_id

if [ $? -eq 0 ]; then
  echo "NSG rule updated/created successfully!"
else
  echo "Error: Failed to update/create NSG rule."
  exit 1
fi
