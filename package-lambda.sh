#!/bin/bash

# Lambda Packaging Script for Athena Query Solution
# This script packages the Lambda function code and dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LAMBDA_DIR="lambda_source/athena_query_lambda"
PACKAGE_DIR="lambda_package"
ZIP_FILE="athena-query-lambda.zip"
LAYER_DIR="lambda_layer"
LAYER_ZIP="python-dependencies-layer.zip"

echo -e "${GREEN}Starting Lambda packaging process...${NC}"

# Clean up previous builds
echo -e "${YELLOW}Cleaning up previous builds...${NC}"
rm -rf $PACKAGE_DIR
rm -rf $LAYER_DIR
rm -f $ZIP_FILE
rm -f $LAYER_ZIP

# Create package directory
mkdir -p $PACKAGE_DIR
mkdir -p $LAYER_DIR/python

# Copy Lambda source code
echo -e "${YELLOW}Copying Lambda source code...${NC}"
cp $LAMBDA_DIR/*.py $PACKAGE_DIR/

# Create Lambda Layer with dependencies
echo -e "${YELLOW}Creating Lambda Layer with dependencies...${NC}"
cd $LAYER_DIR

# Install dependencies to the layer
pip install tenacity==5.0.4 -t python/

# Create layer zip
zip -r ../$LAYER_ZIP python/

cd ..

# Create Lambda function zip
echo -e "${YELLOW}Creating Lambda function package...${NC}"
cd $PACKAGE_DIR
zip -r ../$ZIP_FILE .
cd ..

echo -e "${GREEN}Lambda packaging completed!${NC}"
echo "Lambda function package: $ZIP_FILE"
echo "Lambda layer package: $LAYER_ZIP"
echo ""
echo -e "${YELLOW}To upload to S3:${NC}"
echo "aws s3 cp $ZIP_FILE s3://your-deployment-bucket/lambda/"
echo "aws s3 cp $LAYER_ZIP s3://your-deployment-bucket/layers/"
