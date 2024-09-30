#This script automates the process of updating your Azure NSG rule to whitelist your dynamic public IP using shell scirpting
#sudo apt-get install jq -y

#!/bin/bash

# Variables
subscription_id="<YOUR_SUBSCRIPTION_ID>"
resource_group="<YOUR_RESOURCE_GROUP>"
nsg_name="<YOUR_NSG_NAME>"
nsg_rule_name="<YOUR_NSG_RULE_NAME>"

# Fetch current public IP
public_ip=$(curl -s https://api.ipify.org)

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

# Parse priority, access, and port values from the existing rule
priority=$(echo $nsg_rule | jq '.priority')
access=$(echo $nsg_rule | jq -r '.access')
direction=$(echo $nsg_rule | jq -r '.direction')
protocol=$(echo $nsg_rule | jq -r '.protocol')
destination_port_ranges=$(echo $nsg_rule | jq -r '.destinationPortRanges[]')

# Update NSG rule with the new public IP
echo "Updating NSG rule with new public IP: $public_ip/32"
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
  echo "NSG rule updated successfully!"
else
  echo "Error: Failed to update NSG rule."
  exit 1
fi
