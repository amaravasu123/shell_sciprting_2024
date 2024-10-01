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
destination_port_ranges="${5:-22}"  # Dynamically passed port range, defaults to 22 if not provided

# Fetch current public IP
public_ip=$(curl -s https://api.ipify.org)
if [ -z "$public_ip" ]; then
  echo "Error: Failed to fetch public IP. Check your internet connection."
  exit 1
fi
echo "Your current public IP: $public_ip"

# Get existing NSG rule configuration
nsg_rule=$(az network nsg rule show \
  --resource-group $resource_group \
  --nsg-name $nsg_name \
  --name $nsg_rule_name \
  --subscription $subscription_id)

if [ $? -ne 0 ]; then
  echo "Error: Failed to retrieve NSG rule."
  exit 1
fi

# Backup existing NSG rule configuration
echo $nsg_rule > nsg_rule_backup_$(date +%Y%m%d%H%M%S).json
echo "Backup of existing NSG rule saved."

# Parse priority, access, and port values from the existing rule
priority=$(echo $nsg_rule | jq '.priority')
access=$(echo $nsg_rule | jq -r '.access')
direction=$(echo $nsg_rule | jq -r '.direction')
protocol=$(echo $nsg_rule | jq -r '.protocol')

# Update NSG rule with the new public IP and dynamic port range
log_file="nsg_update_log_$(date +%Y%m%d%H%M%S).log"
echo "Updating NSG rule with new public IP: $public_ip/32 and port range: $destination_port_ranges" | tee -a $log_file
az network nsg rule update \
  --resource-group $resource_group \
  --nsg-name $nsg_name \
  --name $nsg_rule_name \
  --priority $priority \
  --access $access \
  --direction $direction \
  --protocol $protocol \
  --source-address-prefixes "$public_ip/32" \
  --destination-port-ranges $destination_port_ranges \
  --subscription $subscription_id

if [ $? -eq 0 ]; then
  echo "NSG rule updated successfully!" | tee -a $log_file
else
  echo "Error: Failed to update NSG rule." | tee -a $log_file
  exit 1
fi
