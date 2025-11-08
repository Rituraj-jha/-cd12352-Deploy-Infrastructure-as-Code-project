#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT_NAME="Udagram"
NETWORK_STACK_NAME="${ENVIRONMENT_NAME}-Network-Stack"
APPLICATION_STACK_NAME="${ENVIRONMENT_NAME}-Application-Stack"
REGION="us-east-1"  # Change this to match your deployment region
S3_BUCKET_NAME="udagram-static-content-2024-rituraj-08-11-2025"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Function to check if stack exists
stack_exists() {
    aws cloudformation describe-stacks \
        --stack-name "$1" \
        --region "$REGION" \
        --query 'Stacks[0].StackName' \
        --output text 2>/dev/null
}

# Function to wait for stack deletion
wait_for_deletion() {
    local stack_name=$1
    
    echo -e "${YELLOW}⏳ Waiting for $stack_name to be deleted...${NC}"
    aws cloudformation wait stack-delete-complete \
        --stack-name "$stack_name" \
        --region "$REGION"
}

# Confirmation prompt
echo -e "${RED}⚠️  WARNING: This will delete all resources!${NC}"
echo -e "${RED}Stacks to be deleted:${NC}"
echo -e "  1. ${YELLOW}$APPLICATION_STACK_NAME${NC}"
echo -e "  2. ${YELLOW}$NETWORK_STACK_NAME${NC}"
echo -e "\n${RED}S3 Bucket to be emptied:${NC}"
echo -e "  ${YELLOW}$S3_BUCKET_NAME${NC}"
echo -e "\n${RED}All data will be lost, including EC2 instances, Load Balancer, and S3 objects.${NC}"
read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo -e "${GREEN}Deletion cancelled.${NC}"
    exit 0
fi

# =============== EMPTY S3 BUCKET ===============
echo -e "\n${YELLOW}================================${NC}"
echo -e "${YELLOW}Emptying S3 Bucket...${NC}"
echo -e "${YELLOW}================================${NC}"

if [ -n "$S3_BUCKET_NAME" ]; then
    echo -e "${YELLOW}🗑️  Emptying S3 bucket: $S3_BUCKET_NAME${NC}"
    
    # Check if bucket exists
    if aws s3 ls "s3://$S3_BUCKET_NAME" --region "$REGION" 2>/dev/null; then
        # Remove all objects and versions
        aws s3 rm "s3://$S3_BUCKET_NAME" --recursive --region "$REGION"
        echo -e "${GREEN}✅ S3 bucket emptied${NC}"
    else
        echo -e "${YELLOW}⚠️  S3 bucket does not exist or is already empty${NC}"
    fi
fi

# =============== DELETE APPLICATION STACK ===============
echo -e "\n${YELLOW}================================${NC}"
echo -e "${YELLOW}Deleting Application Stack...${NC}"
echo -e "${YELLOW}================================${NC}"

if [ -n "$(stack_exists $APPLICATION_STACK_NAME)" ]; then
    echo -e "${RED}🗑️  Deleting: $APPLICATION_STACK_NAME${NC}"
    
    aws cloudformation delete-stack \
        --stack-name "$APPLICATION_STACK_NAME" \
        --region "$REGION"
    
    wait_for_deletion "$APPLICATION_STACK_NAME"
    
    echo -e "${GREEN}✅ Application Stack deleted successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Application Stack does not exist.${NC}"
fi

# =============== DELETE NETWORK STACK ===============
echo -e "\n${YELLOW}================================${NC}"
echo -e "${YELLOW}Deleting Network Stack...${NC}"
echo -e "${YELLOW}================================${NC}"

if [ -n "$(stack_exists $NETWORK_STACK_NAME)" ]; then
    echo -e "${RED}🗑️  Deleting: $NETWORK_STACK_NAME${NC}"
    
    aws cloudformation delete-stack \
        --stack-name "$NETWORK_STACK_NAME" \
        --region "$REGION"
    
    wait_for_deletion "$NETWORK_STACK_NAME"
    
    echo -e "${GREEN}✅ Network Stack deleted successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Network Stack does not exist.${NC}"
fi

# =============== DELETE S3 BUCKET ===============
echo -e "\n${YELLOW}================================${NC}"
echo -e "${YELLOW}Deleting S3 Bucket...${NC}"
echo -e "${YELLOW}================================${NC}"

if [ -n "$S3_BUCKET_NAME" ]; then
    # Try to delete the bucket (will fail if it contains objects)
    if aws s3api head-bucket --bucket "$S3_BUCKET_NAME" --region "$REGION" 2>/dev/null; then
        echo -e "${RED}🗑️  Deleting S3 bucket: $S3_BUCKET_NAME${NC}"
        
        # Remove bucket versioning
        aws s3api put-bucket-versioning \
            --bucket "$S3_BUCKET_NAME" \
            --versioning-configuration Status=Suspended \
            --region "$REGION" 2>/dev/null || true
        
        # Delete all object versions
        aws s3api delete-objects \
            --bucket "$S3_BUCKET_NAME" \
            --delete "$(aws s3api list-object-versions \
                --bucket "$S3_BUCKET_NAME" \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' \
                --output json | jq -r '.[] | {Key:.Key, VersionId:.VersionId}' | jq -s '.' | jq '{Objects:.}')" \
            --region "$REGION" 2>/dev/null || true
        
        # Delete the bucket
        aws s3 rb "s3://$S3_BUCKET_NAME" --region "$REGION" 2>/dev/null && \
            echo -e "${GREEN}✅ S3 bucket deleted successfully!${NC}" || \
            echo -e "${YELLOW}⚠️  S3 bucket still contains objects and was not deleted${NC}"
    else
        echo -e "${YELLOW}⚠️  S3 bucket does not exist${NC}"
    fi
fi

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "${YELLOW}Note: EBS volumes may take a few minutes to be deleted.${NC}"