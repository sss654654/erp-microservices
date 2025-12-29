#!/bin/bash
set -e

echo "=========================================="
echo "Detecting changed services..."
echo "=========================================="

# 첫 빌드이거나 이전 커밋이 없으면 모든 서비스 빌드
if [ -z "$CODEBUILD_WEBHOOK_PREV_COMMIT" ]; then
  echo "First build or manual trigger, building all services"
  echo "approval-request-service approval-processing-service notification-service" > /tmp/changed_services.txt
  echo "true" > /tmp/lambda_changed.txt
  echo "true" > /tmp/helm_changed.txt
else
  # Git diff로 변경된 파일 확인
  CHANGED_FILES=$(git diff --name-only $CODEBUILD_WEBHOOK_PREV_COMMIT $CODEBUILD_RESOLVED_SOURCE_VERSION)
  echo "Changed files:"
  echo "$CHANGED_FILES"
  
  CHANGED_SERVICES=""
  LAMBDA_CHANGED="false"
  HELM_CHANGED="false"
  
  # Lambda (Employee Service) 변경 확인
  if echo "$CHANGED_FILES" | grep -q "backend/employee-service/"; then
    LAMBDA_CHANGED="true"
    echo "✓ Lambda (employee-service) changed"
  fi
  
  # EKS 서비스 변경 확인
  if echo "$CHANGED_FILES" | grep -q "backend/approval-request-service/"; then
    CHANGED_SERVICES="$CHANGED_SERVICES approval-request-service"
    echo "✓ approval-request-service changed"
  fi
  
  if echo "$CHANGED_FILES" | grep -q "backend/approval-processing-service/"; then
    CHANGED_SERVICES="$CHANGED_SERVICES approval-processing-service"
    echo "✓ approval-processing-service changed"
  fi
  
  if echo "$CHANGED_FILES" | grep -q "backend/notification-service/"; then
    CHANGED_SERVICES="$CHANGED_SERVICES notification-service"
    echo "✓ notification-service changed"
  fi
  
  # Helm Chart 변경 확인
  if echo "$CHANGED_FILES" | grep -q "helm-chart/"; then
    HELM_CHANGED="true"
    echo "✓ Helm Chart changed, will deploy all EKS services"
    CHANGED_SERVICES="approval-request-service approval-processing-service notification-service"
  fi
  
  echo "$CHANGED_SERVICES" > /tmp/changed_services.txt
  echo "$LAMBDA_CHANGED" > /tmp/lambda_changed.txt
  echo "$HELM_CHANGED" > /tmp/helm_changed.txt
fi

echo "Services to build: $(cat /tmp/changed_services.txt)"
echo "Lambda changed: $(cat /tmp/lambda_changed.txt)"
echo "Helm changed: $(cat /tmp/helm_changed.txt)"
echo "=========================================="
