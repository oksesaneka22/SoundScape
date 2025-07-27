#!/bin/bash

# Set your EKS cluster name
CLUSTER_NAME="kubik"

# Fetch the node group name from EKS
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --output text --query "nodegroups[0]")

# Fetch the IAM role associated with the node group
NODE_ROLE=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODEGROUP_NAME --query "nodegroup.nodeRole" --output text)

# Attach the AmazonS3FullAccess policy to the IAM role
aws iam attach-role-policy --role-name $(basename $NODE_ROLE) --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Output the IAM role and node group for reference
echo "Node group: $NODEGROUP_NAME"
echo "IAM Role: $NODE_ROLE"
echo "AmazonS3FullAccess policy has been attached."
