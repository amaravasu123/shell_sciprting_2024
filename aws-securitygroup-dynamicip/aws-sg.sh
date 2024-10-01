#Shell Script to Update AWS Security Group Rule with Public IP:

#!/bin/bash

# Check AWS CLI authentication
aws sts get-caller-identity > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: You must configure your AWS CLI with 'aws configure'."
  exit 1
fi

# Variables (accept as parameters)
security_group_name="${1:-<YOUR_SECURITY_GROUP_NAME>}" # Name of the security group
vpc_id="${2:-<YOUR_VPC_ID>}"                            # VPC ID where the security group will be created
destination_port_ranges="${3:-22}"                       # Dynamically passed port range, defaults to 22 (SSH) if not provided

# Fetch current public IP
public_ip=$(curl -s https://api.ipify.org)
if [ -z "$public_ip" ]; then
  echo "Error: Failed to fetch public IP. Check your internet connection."
  exit 1
fi
echo "Your current public IP: $public_ip"

# Check if the Security Group exists
sg_id=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$security_group_name" --query "SecurityGroups[0].GroupId" --output text)

if [ "$sg_id" == "None" ]; then
  # Create the Security Group if it does not exist
  echo "Security Group '$security_group_name' not found. Creating a new Security Group..."
  sg_id=$(aws ec2 create-security-group --group-name $security_group_name --description "Security Group for dynamic IP updates" --vpc-id $vpc_id --query "GroupId" --output text)

  if [ $? -ne 0 ]; then
    echo "Error: Failed to create Security Group."
    exit 1
  fi

  echo "Security Group created with ID: $sg_id"
else
  echo "Using existing Security Group with ID: $sg_id"
fi

# Check if the rule for the port already exists
existing_rule=$(aws ec2 describe-security-groups --group-ids $sg_id --query "SecurityGroups[0].IpPermissions[?ToPort==\`$destination_port_ranges\`]" --output text)

# If the rule exists, revoke it
if [ -n "$existing_rule" ]; then
  echo "Revoking old security group rule..."
  aws ec2 revoke-security-group-ingress \
    --group-id $sg_id \
    --protocol tcp \
    --port $destination_port_ranges \
    --cidr "$public_ip/32"
  
  if [ $? -ne 0 ]; then
    echo "Error: Failed to revoke old Security Group rule."
    exit 1
  fi
fi

# Authorize new security group rule with the new public IP
echo "Authorizing new security group rule with public IP: $public_ip/32 and port: $destination_port_ranges"
aws ec2 authorize-security-group-ingress \
  --group-id $sg_id \
  --protocol tcp \
  --port $destination_port_ranges \
  --cidr "$public_ip/32"

if [ $? -eq 0 ]; then
  echo "Security Group rule updated successfully!"
else
  echo "Error: Failed to update Security Group rule."
  exit 1
fi
 