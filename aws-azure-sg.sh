#!/bin/bash

# Function to update AWS Security Group
update_aws_sg() {
    # Variables
    security_group_name="${1:-<YOUR_SECURITY_GROUP_NAME>}"
    vpc_id="${2:-<YOUR_VPC_ID>}"
    destination_port_ranges="${3:-22}"

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
      echo "Creating a new Security Group in AWS..."
      sg_id=$(aws ec2 create-security-group --group-name $security_group_name --description "Dynamic SG for public IP updates" --vpc-id $vpc_id --query "GroupId" --output text)

      if [ $? -ne 0 ]; then
        echo "Error: Failed to create Security Group."
        exit 1
      fi
      echo "Security Group created with ID: $sg_id"
    else
      echo "Using existing Security Group with ID: $sg_id"
    fi

    # Revoke old rule and add new one with current public IP
    existing_rule=$(aws ec2 describe-security-groups --group-ids $sg_id --query "SecurityGroups[0].IpPermissions[?ToPort==\`$destination_port_ranges\`]" --output text)
    if [ -n "$existing_rule" ]; then
      echo "Revoking old security group rule..."
      aws ec2 revoke-security-group-ingress --group-id $sg_id --protocol tcp --port $destination_port_ranges --cidr "$public_ip/32"
    fi

    echo "Authorizing new security group rule..."
    aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port $destination_port_ranges --cidr "$public_ip/32"

    if [ $? -eq 0 ]; then
      echo "AWS Security Group updated successfully!"
    else
      echo "Error: Failed to update AWS Security Group."
      exit 1
    fi
}

# Function to update Azure NSG
update_azure_nsg() {
    # Variables
    subscription_id="${1:-<YOUR_SUBSCRIPTION_ID>}"
    resource_group="${2:-<YOUR_RESOURCE_GROUP>}"
    nsg_name="${3:-<YOUR_NSG_NAME>}"
    nsg_rule_name="${4:-<YOUR_NSG_RULE_NAME>}"
    location="${5:-<YOUR_LOCATION>}"
    destination_port_ranges="${6:-22}"

    # Fetch current public IP
    public_ip=$(curl -s https://api.ipify.org)
    if [ -z "$public_ip" ]; then
      echo "Error: Failed to fetch public IP. Check your internet connection."
      exit 1
    fi
    echo "Your current public IP: $public_ip"

    # Check if NSG exists
    nsg=$(az network nsg show --resource-group $resource_group --name $nsg_name --subscription $subscription_id --query id --output tsv)
    if [ -z "$nsg" ]; then
      echo "Creating NSG in Azure..."
      az network nsg create --resource-group $resource_group --name $nsg_name --location $location --subscription $subscription_id
      if [ $? -ne 0 ]; then
        echo "Error: Failed to create NSG."
        exit 1
      fi
      echo "NSG created with name: $nsg_name"
    else
      echo "Using existing NSG: $nsg_name"
    fi

    # Check if NSG rule exists
    nsg_rule=$(az network nsg rule show --resource-group $resource_group --nsg-name $nsg_name --name $nsg_rule_name --subscription $subscription_id --query id --output tsv)
    if [ -n "$nsg_rule" ]; then
      echo "Deleting old NSG rule..."
      az network nsg rule delete --resource-group $resource_group --nsg-name $nsg_name --name $nsg_rule_name --subscription $subscription_id
    fi

    echo "Creating new NSG rule..."
    az network nsg rule create --resource-group $resource_group --nsg-name $nsg_name --name $nsg_rule_name --priority 1000 --source-address-prefixes "$public_ip/32" --destination-port-ranges $destination_port_ranges --access Allow --protocol Tcp --direction Inbound --subscription $subscription_id

    if [ $? -eq 0 ]; then
      echo "Azure NSG rule updated successfully!"
    else
      echo "Error: Failed to update Azure NSG rule."
      exit 1
    fi
}

# Main execution
if [ "$1" == "aws" ]; then
    update_aws_sg $2 $3 $4
elif [ "$1" == "azure" ]; then
    update_azure_nsg $2 $3 $4 $5 $6 $7
else
    echo "Usage: $0 <aws|azure> <parameters...>"
    exit 1
fi
