#!/bin/bash

ENVIRONMENT_NAME="Udagram"
NETWORK_STACK_NAME="${ENVIRONMENT_NAME}-Network-Stack"
APPLICATION_STACK_NAME="${ENVIRONMENT_NAME}-Application-Stack"
REGION="us-east-1"

# Network Stack
aws cloudformation create-stack \
  --stack-name "$NETWORK_STACK_NAME" \
  --template-body file://./starter/network.yml \
  --parameters file://./starter/network-parameters.json \
  --region "$REGION" \
  --tags Key=Project,Value=Udagram

aws cloudformation wait stack-create-complete --stack-name "$NETWORK_STACK_NAME" --region "$REGION"

echo "✅ Network Stack Created"

# Application Stack (SIMPLIFIED - NO IAM)
aws cloudformation create-stack \
  --stack-name "$APPLICATION_STACK_NAME" \
  --template-body file://./starter/udagram-simplified.yml \
  --parameters file://./starter/udagram-parameters.json \
  --region "$REGION" \
  --tags Key=Project,Value=Udagram

aws cloudformation wait stack-create-complete --stack-name "$APPLICATION_STACK_NAME" --region "$REGION"

echo "✅ Application Stack Created"

# Display Load Balancer URL
LB_URL=$(aws cloudformation describe-stacks \
  --stack-name "$APPLICATION_STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text)

echo ""
echo "🌐 Load Balancer URL: $LB_URL"