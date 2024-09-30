#Shell Script to Update AWS Security Group Rule with Public IP:

#!/bin/bash

# Variables
security_group_id="<YOUR_SECURITY_GROUP_ID>"
region="us-east-1"  # Replace with your AWS region
port="<YOUR_PORT>"  # Replace with the port number for the rule (e.g., 22 for SSH)

# Fetch current public IP
public_ip=$(curl -s https://api.ipify.org)

echo "Your current public IP: $public_ip"

# Fetch the existing security group rule for the specified port
existing_rule=$(aws ec2 describe-security-groups --group-ids $security_group_id --region $region | jq -r \
    --arg port "$port" '.SecurityGroups[0].IpPermissions[] | select(.FromPort == ($port | tonumber))')

if [ -z "$existing_rule" ]; then
    echo "Error: No existing rule found for port $port in Security Group $security_group_id."
    exit 1
fi

# Extract the current CIDR block for the rule
current_cidr=$(echo $existing_rule | jq -r '.IpRanges[0].CidrIp')

echo "Current CIDR for the rule: $current_cidr"

# Revoke the existing rule
aws ec2 revoke-security-group-ingress \
  --group-id $security_group_id \
  --protocol tcp \
  --port $port \
  --cidr $current_cidr \
  --region $region

if [ $? -eq 0 ]; then
    echo "Revoked existing rule with CIDR $current_cidr"
else
    echo "Error: Failed to revoke the existing rule."
    exit 1
fi

# Authorize the new rule with the updated public IP
aws ec2 authorize-security-group-ingress \
  --group-id $security_group_id \
  --protocol tcp \
  --port $port \
  --cidr "$public_ip/32" \
  --region $region

if [ $? -eq 0 ]; then
    echo "Security Group rule updated successfully with new IP: $public_ip/32"
else
    echo "Error: Failed to update Security Group rule."
    exit 1
fi
