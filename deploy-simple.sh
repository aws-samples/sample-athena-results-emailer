#!/bin/bash

# Simple CloudFormation Deployment Script for Athena Query Solution
# Usage: ./deploy-simple.sh [stack-name] [region]

set -e

# Default values
STACK_NAME=${1:-"athena-query-simple"}
REGION=${2:-"eu-west-1"}
TEMPLATE_FILE="athena-query-solution-simple.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Simple CloudFormation deployment...${NC}"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Template: $TEMPLATE_FILE"
echo ""

# Prompt for email addresses
read -p "Enter sender email address (must be verified in SES): " SENDER_EMAIL
read -p "Enter receiver email address (must be verified in SES): " RECEIVER_EMAIL
read -p "Enter Athena database name: " ATHENA_DATABASE
read -p "Enter Athena table name: " ATHENA_TABLE

# Validate inputs
if [[ -z "$SENDER_EMAIL" || -z "$RECEIVER_EMAIL" || -z "$ATHENA_DATABASE" || -z "$ATHENA_TABLE" ]]; then
    echo -e "${RED}All fields are required!${NC}"
    exit 1
fi

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
    --parameters \
        ParameterKey=SenderEmail,ParameterValue="$SENDER_EMAIL" \
        ParameterKey=ReceiverEmail,ParameterValue="$RECEIVER_EMAIL" \
        ParameterKey=AthenaDatabase,ParameterValue="$ATHENA_DATABASE" \
        ParameterKey=AthenaTable,ParameterValue="$ATHENA_TABLE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION \
    --tags Key=Project,Value=Penny Key=Team,Value=FinOps

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
        exit 1
    fi
else
    echo -e "${RED}Stack deployment failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Important Next Steps:${NC}"
echo "1. Verify that both email addresses are verified in SES:"
echo "   - Go to SES Console > Email Addresses"
echo "   - Verify both $SENDER_EMAIL and $RECEIVER_EMAIL"
echo "2. Test the Lambda function manually in the AWS Console"
echo "3. Check CloudWatch Logs for any issues"
echo "4. The query will run automatically based on the schedule: cron(07 1 * ? * *)"
