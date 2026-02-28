#!/bin/bash

# Build script for Google Ads Lambda functions
set -e

PROJECT_NAME="${PROJECT_NAME:-ecommerce-platform}"
REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "🚀 Building Google Ads Lambda functions for ${PROJECT_NAME} in ${ENVIRONMENT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to build and package Lambda
build_lambda() {
    local function_name=$1
    local function_path="lambda/${function_name}"
    
    echo -e "${YELLOW}Building ${function_name}...${NC}"
    
    if [ ! -d "$function_path" ]; then
        echo -e "${RED}Error: Directory ${function_path} not found${NC}"
        exit 1
    fi
    
    cd "$function_path"
    
    # Check if go.mod exists
    if [ ! -f "go.mod" ]; then
        echo -e "${RED}Error: go.mod not found in ${function_path}${NC}"
        exit 1
    fi
    
    # Download dependencies
    echo "Downloading dependencies..."
    go mod tidy
    go mod download
    
    # Build for Linux
    echo "Building binary..."
    GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-w -s" -o main main.go
    
    # Check if build was successful
    if [ ! -f "main" ]; then
        echo -e "${RED}Error: Build failed for ${function_name}${NC}"
        exit 1
    fi
    
    # Create zip file
    echo "Creating zip package..."
    zip -r "../${function_name}.zip" main
    
    # Clean up
    rm main
    
    cd - > /dev/null
    
    echo -e "${GREEN}✅ Successfully built ${function_name}${NC}"
}

# Build all Lambda functions
functions=("campaign-monitor" "bid-optimizer" "ad-analytics")

for function in "${functions[@]}"; do
    build_lambda "$function"
done

echo -e "${GREEN}🎉 All Lambda functions built successfully!${NC}"

# Display file sizes
echo -e "${YELLOW}Package sizes:${NC}"
for function in "${functions[@]}"; do
    if [ -f "lambda/${function}.zip" ]; then
        size=$(du -h "lambda/${function}.zip" | cut -f1)
        echo "  ${function}.zip: ${size}"
    fi
done

# Instructions for deployment
echo -e "${YELLOW}To deploy these functions:${NC}"
echo "1. Upload zip files to Lambda functions"
echo "2. Or run: terraform apply to update functions automatically"
echo "3. Check CloudWatch logs for deployment status"

# Optional: Deploy to Lambda if AWS CLI is available
if command -v aws &> /dev/null; then
    echo -e "${YELLOW}Deploying to Lambda functions...${NC}"
    
    for function in "${functions[@]}"; do
        lambda_function_name="${PROJECT_NAME}-${function}"
        
        echo "Updating ${lambda_function_name}..."
        
        aws lambda update-function-code \
            --function-name "$lambda_function_name" \
            --zip-file "fileb://lambda/${function}.zip" \
            --region "$REGION" \
            --no-cli-pager || echo -e "${RED}Failed to update ${lambda_function_name}${NC}"
    done
    
    echo -e "${GREEN}✅ Deployment completed!${NC}"
else
    echo -e "${YELLOW}AWS CLI not found. Manual deployment required.${NC}"
fi

echo -e "${GREEN}🚀 Build process completed!${NC}"
