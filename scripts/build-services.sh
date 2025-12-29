#!/bin/bash
set -e

CHANGED_SERVICES=$(cat /tmp/changed_services.txt)
LAMBDA_CHANGED=$(cat /tmp/lambda_changed.txt)

echo "=========================================="
echo "Building services..."
echo "=========================================="

# Lambda (Employee Service) 빌드
if [ "$LAMBDA_CHANGED" = "true" ]; then
  echo "Building Lambda: employee-service"
  cd backend/employee-service
  mvn clean package -DskipTests
  LAMBDA_REPO=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda
  docker build -f Dockerfile.lambda -t $LAMBDA_REPO:latest .
  docker tag $LAMBDA_REPO:latest $LAMBDA_REPO:$IMAGE_TAG
  docker push $LAMBDA_REPO:latest
  docker push $LAMBDA_REPO:$IMAGE_TAG
  echo "✓ Lambda build completed"
  cd ../..
else
  echo "Skipping Lambda build (no changes)"
fi

# EKS 서비스 빌드
if [ -n "$CHANGED_SERVICES" ]; then
  for SERVICE in $CHANGED_SERVICES; do
    echo "Building EKS service: $SERVICE"
    cd backend/$SERVICE
    mvn clean package -DskipTests
    REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/$SERVICE
    docker build -t $REPOSITORY_URI:latest .
    docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
    docker push $REPOSITORY_URI:latest
    docker push $REPOSITORY_URI:$IMAGE_TAG
    echo "✓ $SERVICE build completed"
    cd ../..
  done
else
  echo "No EKS services to build"
fi

echo "=========================================="
