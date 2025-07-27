#!/bin/bash

set -e  # Exit on error
set -o pipefail  # Catch pipeline errors

REGION="eu-north-1"

echo "Fetching Kubernetes Nodes..."
NODES_JSON=$(sudo kubectl get nodes -o json)

# Extract instance IDs from node annotations
NODE1_INSTANCE_ID=$(echo "$NODES_JSON" | jq -r '.items[0].metadata.annotations."csi.volume.kubernetes.io/nodeid"' | cut -d: -f2 | tr -d '"}')
NODE2_INSTANCE_ID=$(echo "$NODES_JSON" | jq -r '.items[1].metadata.annotations."csi.volume.kubernetes.io/nodeid"' | cut -d: -f2 | tr -d '"}')

echo "Node 1 Instance ID: $NODE1_INSTANCE_ID"
echo "Node 2 Instance ID: $NODE2_INSTANCE_ID"

# Fetch network interface IDs for each node
ENI1=$(aws ec2 describe-instances --instance-ids "$NODE1_INSTANCE_ID" --region "$REGION" --query 'Reservations[*].Instances[*].NetworkInterfaces[0].NetworkInterfaceId' --output text)
ENI2=$(aws ec2 describe-instances --instance-ids "$NODE1_INSTANCE_ID" --region "$REGION" --query 'Reservations[*].Instances[*].NetworkInterfaces[1].NetworkInterfaceId' --output text)
ENI3=$(aws ec2 describe-instances --instance-ids "$NODE2_INSTANCE_ID" --region "$REGION" --query 'Reservations[*].Instances[*].NetworkInterfaces[0].NetworkInterfaceId' --output text)
ENI4=$(aws ec2 describe-instances --instance-ids "$NODE2_INSTANCE_ID" --region "$REGION" --query 'Reservations[*].Instances[*].NetworkInterfaces[1].NetworkInterfaceId' --output text)

echo "Network Interfaces: $ENI1, $ENI2, ENI3, ENI4"

# Fetch security groups for each ENI
SG1=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI1" --region "$REGION" --query 'NetworkInterfaces[0].Groups[*].GroupId' --output text)
SG2=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI2" --region "$REGION" --query 'NetworkInterfaces[0].Groups[*].GroupId' --output text)

echo "Security Groups for ENI 1: $SG1"
echo "Security Groups for ENI 2: $SG2"

# Fetch the valid Kubernetes security group dynamically
VALID_SECURITY_GROUP=$(aws ec2 describe-security-groups --region "$REGION" --query "SecurityGroups[?starts_with(GroupName, 'eks-cluster-sg-kubik')].GroupId" --output text)

if [[ -z "$VALID_SECURITY_GROUP" ]]; then
    echo "Error: No valid EKS security group found!"
    exit 1
fi

echo "Valid EKS Security Group: $VALID_SECURITY_GROUP"

# Identify unwanted security groups
UNWANTED_SG1=()
for sg in $SG1; do
    [[ "$sg" != "$VALID_SECURITY_GROUP" ]] && UNWANTED_SG1+=("$sg")
done

UNWANTED_SG2=()
for sg in $SG2; do
    [[ "$sg" != "$VALID_SECURITY_GROUP" ]] && UNWANTED_SG2+=("$sg")
done

echo "Updating security groups for network interfaces..."
aws ec2 modify-network-interface-attribute --network-interface-id "$ENI1" --groups "$VALID_SECURITY_GROUP" --region "$REGION"
aws ec2 modify-network-interface-attribute --network-interface-id "$ENI2" --groups "$VALID_SECURITY_GROUP" --region "$REGION"
aws ec2 modify-network-interface-attribute --network-interface-id "$ENI3" --groups "$VALID_SECURITY_GROUP" --region "$REGION"
aws ec2 modify-network-interface-attribute --network-interface-id "$ENI4" --groups "$VALID_SECURITY_GROUP" --region "$REGION"

echo "Successfully removed unwanted security groups."

# Fetch EFS ID dynamically (assuming you have only one EFS)
EFS_ID=$(aws efs describe-file-systems --region "$REGION" --query 'FileSystems[0].FileSystemId' --output text)

if [[ -z "$EFS_ID" ]]; then
    echo "Error: No EFS found!"
    exit 1
fi

echo "EFS ID: $EFS_ID"

# Fetch all mount target IDs for the EFS
MOUNT_TARGET_IDS=$(aws efs describe-mount-targets --file-system-id "$EFS_ID" --region "$REGION" --query 'MountTargets[*].MountTargetId' --output text)

if [[ -z "$MOUNT_TARGET_IDS" ]]; then
    echo "Error: No mount targets found for EFS!"
    exit 1
fi

echo "Mount Target IDs: $MOUNT_TARGET_IDS"

# Attach the valid security group to each mount target
for MOUNT_TARGET_ID in $MOUNT_TARGET_IDS; do
    echo "Attaching security group $VALID_SECURITY_GROUP to EFS mount target $MOUNT_TARGET_ID..."
    aws efs modify-mount-target-security-groups --mount-target-id "$MOUNT_TARGET_ID" --security-groups "$VALID_SECURITY_GROUP" --region "$REGION"
    echo "Successfully attached the security group to mount target $MOUNT_TARGET_ID."
done
