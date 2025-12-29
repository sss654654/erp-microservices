#!/bin/bash
set -e

IMAGE_TAG=$(cat /tmp/image_tag.txt)
CHANGED_SERVICES=$(cat /tmp/changed_services.txt)
LAMBDA_CHANGED=$(cat /tmp/lambda_changed.txt)
HELM_CHANGED=$(cat /tmp/helm_changed.txt)

echo "=========================================="
echo "Deploying services..."
echo "=========================================="

# Lambda 함수 업데이트
if [ "$LAMBDA_CHANGED" = "true" ]; then
  echo "Updating Lambda function..."
  aws lambda update-function-code \
    --function-name $PROJECT_NAME-$ENVIRONMENT-employee-service \
    --image-uri $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:$IMAGE_TAG \
    --region $AWS_REGION
  echo "✓ Lambda function updated"
fi

# Helm Chart values 업데이트
if [ -n "$CHANGED_SERVICES" ] || [ "$HELM_CHANGED" = "true" ]; then
  echo "Updating Helm Chart values..."
  
  for SERVICE in $CHANGED_SERVICES; do
    case $SERVICE in
      "approval-request-service")
        SERVICE_KEY="approvalRequest"
        ;;
      "approval-processing-service")
        SERVICE_KEY="approvalProcessing"
        ;;
      "notification-service")
        SERVICE_KEY="notification"
        ;;
    esac
    
    echo "Updating $SERVICE_KEY image tag to $IMAGE_TAG"
    yq eval ".services.$SERVICE_KEY.image.tag = \"$IMAGE_TAG\"" -i helm-chart/values-dev.yaml
  done
  
  echo "✓ Helm values updated"
  
  # Helm 배포
  echo "Deploying to EKS with Helm..."
  helm upgrade erp-microservices ./helm-chart \
    --values ./helm-chart/values-dev.yaml \
    --namespace erp-dev \
    --install \
    --wait \
    --timeout 5m
  
  echo "✓ Helm deployment completed"
  
  # 배포 상태 확인
  echo "Checking deployment status..."
  kubectl get pods -n erp-dev
  kubectl get svc -n erp-dev
else
  echo "No Helm deployment needed"
fi

echo "=========================================="
echo "Deployment completed on $(date)"
echo "Image tag: $IMAGE_TAG"
echo "Services deployed: $CHANGED_SERVICES"
echo "Lambda updated: $LAMBDA_CHANGED"
echo "=========================================="
