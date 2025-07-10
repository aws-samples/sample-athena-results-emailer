#!/bin/bash

# CloudFormation Deployment Script for Athena Query Solution
# Usage: ./deploy.sh [stack-name] [region] [environment]

set -e

# Default values
STACK_NAME=${1:-"athena-query-solution"}
REGION=${2:-"eu-west-1"}
ENVIRONMENT=${3:-""}
TEMPLATE_FILE="athena-query-solution-advanced.yaml"
PARAMETERS_FILE="parameters.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting CloudFormation deployment...${NC}"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo "Template: $TEMPLATE_FILE"
echo "Parameters: $PARAMETERS_FILE"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}Template file $TEMPLATE_FILE not found!${NC}"
    exit 1
fi

# Check if parameters file exists
if [ ! -f "$PARAMETERS_FILE" ]; then
    echo -e "${RED}Parameters file $PARAMETERS_FILE not found!${NC}"
    exit 1
fi

# Validate the template
echo -e "${YELLOW}Validating CloudFormation template...${NC}"
aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Template validation successful!${NC}"
else
    echo -e "${RED}Template validation failed!${NC}"
    exit 1
fi

# Check if stack exists
STACK_EXISTS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].StackName' \
    --output text 2>/dev/null || echo "NONE")

if [ "$STACK_EXISTS" != "NONE" ]; then
    echo -e "${YELLOW}Stack $STACK_NAME already exists. Updating...${NC}"
    OPERATION="update-stack"
    WAIT_CONDITION="stack-update-complete"
else
    echo -e "${YELLOW}Creating new stack $STACK_NAME...${NC}"
    OPERATION="create-stack"
    WAIT_CONDITION="stack-create-complete"
fi

# Deploy the stack
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"
aws cloudformation $OPERATION \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters file://$PARAMETERS_FILE \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION \
    --tags Key=Project,Value=Penny Key=Team,Value=FinOps Key=Environment,Value=$ENVIRONMENT

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Stack deployment initiated successfully!${NC}"
    
    # Wait for stack operation to complete
    echo -e "${YELLOW}Waiting for stack operation to complete...${NC}"
    aws cloudformation wait $WAIT_CONDITION \
        --stack-name $STACK_NAME \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Stack operation completed successfully!${NC}"
        
        # Display stack outputs
        echo -e "${YELLOW}Stack Outputs:${NC}"
        aws cloudformation describe-stacks \
            --stack-name $STACK_NAME \
            --region $REGION \
            --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
            --output table
    else
        echo -e "${RED}Stack operation failed!${NC}"
        
        # Show stack events for debugging
        echo -e "${YELLOW}Recent stack events:${NC}"
        aws cloudformation describe-stack-events \
            --stack-name $STACK_NAME \
            --region $REGION \
            --query 'StackEvents[0:10].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
            --output table
        exit 1
    fi
else
    echo -e "${RED}Stack deployment failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Verify that your SES email addresses are verified in the AWS Console"
echo "2. Test the Lambda function manually if needed"
echo "3. Check CloudWatch Logs for any issues"
echo "4. Monitor the scheduled execution"
