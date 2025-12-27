# ERP 프로젝트 완전 분석 및 재구축 마스터 가이드

**작성일**: 2024-12-27  
**목적**: Terraform, Backend, Manifests 전체 분석 및 CodePipeline 강점을 살린 CI/CD 재구축

---

## 📋 목차

1. [전체 분석 요약](#1-전체-분석-요약)
2. [Terraform 상세 분석](#2-terraform-상세-분석)
3. [Backend 코드 분석](#3-backend-코드-분석)
4. [Manifests 분석](#4-manifests-분석)
5. [CodePipeline 강점을 살린 CI/CD 설계](#5-codepipeline-강점을-살린-cicd-설계)
6. [재구축 마스터 플랜](#6-재구축-마스터-플랜)

---

## 1. 전체 분석 요약

### 현재 상태

**✅ 잘 구성된 것:**
- Terraform 인프라 (VPC, EKS, RDS, NLB, API Gateway 등)
- Backend 코드 (Spring Boot, Kafka, MongoDB, Redis)
- 기본 동작 (API 호출, 데이터 저장, 메시징)

**❌ 문제점:**
1. **CI/CD**: 서비스별 파이프라인 (4개), kubectl set image만 실행
2. **Manifests**: Plain YAML, 환경 분리 불가, 중복 코드
3. **Secret**: 평문 하드코딩
4. **NLB**: Kubernetes LoadBalancer 중복 생성
5. **Lambda**: 미사용 (비용 최적화 기회 놓침)

### 재구축 목표

**CodePipeline/CodeBuild 강점 극대화:**
1. AWS Secrets Manager 통합
2. Parameter Store 활용
3. CodeBuild 환경 변수 암호화
4. ECR 이미지 스캔 자동화
5. CloudWatch Logs 중앙 집중
6. X-Ray 트레이싱 통합
7. 단일 파이프라인 + Helm Chart

---

## 2. Terraform 상세 분석

### 2.1 현재 구조 (✅ 문제 없음)

```
infrastructure/terraform/dev/
├── erp-dev-VPC/              # VPC, Subnet, NAT Gateway
├── erp-dev-SecurityGroups/   # 4개 SG (세분화)
├── erp-dev-IAM/              # 4개 Role (통합)
├── erp-dev-Databases/        # RDS, ElastiCache
├── erp-dev-EKS/              # Cluster, Node Group
├── erp-dev-APIGateway/       # NLB, VPC Link, API Gateway
├── erp-dev-Frontend/         # S3, CloudFront
└── erp-dev-Cognito/          # User Pool
```

**모든 리소스 사용 중, 수정 불필요**

### 2.2 추가 필요: Lambda (선택)

**Employee Service를 Lambda로 전환 (비용 21% 절감)**

**새 Terraform 모듈:**
```
infrastructure/terraform/dev/erp-dev-Lambda/
├── main.tf
├── lambda.tf
├── iam.tf
└── api-gateway-integration.tf
```

**lambda.tf:**
```hcl
resource "aws_lambda_function" "employee" {
  function_name = "erp-dev-employee-service"
  role          = aws_iam_role.lambda.arn
  
  # ECR 이미지 사용
  package_type = "Image"
  image_uri    = "806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service:latest"
  
  # VPC 설정 (RDS 접근)
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }
  
  # 환경 변수 (Secrets Manager 참조)
  environment {
    variables = {
      SPRING_DATASOURCE_URL      = "jdbc:mysql://${var.rds_endpoint}:3306/erp"
      SPRING_DATASOURCE_USERNAME = aws_secretsmanager_secret_version.db_username.secret_string
      SPRING_DATASOURCE_PASSWORD = aws_secretsmanager_secret_version.db_password.secret_string
    }
  }
  
  memory_size = 512
  timeout     = 30
}
```

**api-gateway-integration.tf:**
```hcl
# Lambda 직접 통합 (VPC Link 불필요)
resource "aws_apigatewayv2_integration" "employee_lambda" {
  api_id             = var.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.employee.invoke_arn
  payload_format_version = "2.0"
}

# Lambda 권한
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.employee.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}
```

**장점:**
- VPC Link 불필요 (API Gateway → Lambda 직접 통합)
- EKS Pod 2개 감소 (8개 → 6개)
- 비용 21% 절감 ($82.30 → $64.73)

**단점:**
- Cold Start 300~500ms (첫 요청만)
- 복잡도 증가

**결정:** 선택 사항 (Phase 8에서 구현)

---

## 3. Backend 코드 분석

### 3.1 Employee Service (✅ Lambda 전환 가능)

**특징:**
- 간단한 CRUD (MySQL)
- 실행 시간 200ms
- Kafka 의존성 없음
- WebSocket 없음

**Lambda 전환 시 수정 불필요:**
- Spring Boot는 Lambda에서 그대로 동작
- AWS Lambda Web Adapter 사용

### 3.2 Approval Services (❌ Lambda 불가)

**특징:**
- Kafka Consumer 장시간 실행
- 서비스 간 메시징
- Lambda 15분 제한 초과

**EKS 유지 필수**

### 3.3 Notification Service (❌ Lambda 불가)

**특징:**
- WebSocket 연결 유지
- Lambda는 요청-응답 모델만 지원

**EKS 유지 필수**

### 3.4 Secret 하드코딩 문제

**현재:**
```yaml
# manifests/base/secret.yaml
stringData:
  MYSQL_PASSWORD: "123456789"  # ⚠️ Git에 평문
```

**해결: AWS Secrets Manager**
```yaml
# Helm Chart
env:
- name: MYSQL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password

# External Secrets Operator가 Secrets Manager에서 자동 동기화
```

---

## 4. Manifests 분석

### 4.1 현재 문제

**중복 코드:**
- 4개 Deployment 파일 (거의 동일)
- 4개 Service 파일
- 4개 HPA 파일
- 총 400줄 중 300줄 중복

**환경 분리 불가:**
- 개발계/운영계 설정 하드코딩
- values 파일 없음

**LoadBalancer 중복:**
```yaml
# notification-service.yaml
spec:
  type: LoadBalancer  # ⚠️ NLB 추가 생성
```

### 4.2 Helm Chart로 해결

**1개 템플릿으로 4개 서비스 생성:**
```yaml
# templates/deployment.yaml
{{- range $key, $service := .Values.services }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $service.name }}
spec:
  replicas: {{ $service.replicaCount }}
  # ... 모든 서비스 동일 구조
{{- end }}
```

**환경별 values:**
```yaml
# values-dev.yaml
services:
  employee:
    replicaCount: 2
    
# values-prod.yaml
services:
  employee:
    replicaCount: 5
```

---

## 5. CodePipeline 강점을 살린 CI/CD 설계

### 5.1 CGV (GitLab + ArgoCD) vs ERP (CodePipeline)

| 기능 | CGV | ERP (개선 후) |
|------|-----|--------------|
| **Secret 관리** | GitLab Variables | AWS Secrets Manager ✅ |
| **이미지 스캔** | 수동 | ECR 자동 스캔 ✅ |
| **로그 관리** | GitLab Logs | CloudWatch Logs ✅ |
| **트레이싱** | 없음 | X-Ray 통합 ✅ |
| **비용** | GitLab 서버 필요 | 사용량 기반 ✅ |
| **AWS 통합** | 제한적 | 네이티브 통합 ✅ |
| **Drift Detection** | ArgoCD ✅ | 없음 ❌ |

### 5.2 CodePipeline 강점 극대화 전략

#### 1) AWS Secrets Manager 통합

**buildspec.yml:**
```yaml
env:
  secrets-manager:
    DOCKER_HUB_TOKEN: prod/dockerhub:token
    DB_PASSWORD: prod/rds:password
    MONGODB_URI: prod/mongodb:uri
```

**장점:**
- Git에 Secret 없음
- 자동 로테이션
- 감사 로그

#### 2) Parameter Store 활용

**buildspec.yml:**
```yaml
env:
  parameter-store:
    ECR_REPOSITORY: /erp/dev/ecr/repository
    EKS_CLUSTER_NAME: /erp/dev/eks/cluster-name
    HELM_CHART_VERSION: /erp/dev/helm/version
```

**장점:**
- 중앙 집중 설정
- 버전 관리
- 무료 (Standard)

#### 3) ECR 이미지 스캔 자동화

**buildspec.yml:**
```yaml
post_build:
  commands:
    # ECR 푸시
    - docker push $ECR_REPOSITORY:$IMAGE_TAG
    
    # 이미지 스캔 시작
    - aws ecr start-image-scan --repository-name erp/employee-service --image-id imageTag=$IMAGE_TAG
    
    # 스캔 결과 대기
    - |
      while true; do
        SCAN_STATUS=$(aws ecr describe-image-scan-findings --repository-name erp/employee-service --image-id imageTag=$IMAGE_TAG --query 'imageScanStatus.status' --output text)
        if [ "$SCAN_STATUS" = "COMPLETE" ]; then
          break
        fi
        sleep 5
      done
    
    # 취약점 확인
    - |
      CRITICAL=$(aws ecr describe-image-scan-findings --repository-name erp/employee-service --image-id imageTag=$IMAGE_TAG --query 'imageScanFindings.findingSeverityCounts.CRITICAL' --output text)
      if [ "$CRITICAL" != "None" ] && [ "$CRITICAL" -gt 0 ]; then
        echo "Critical vulnerabilities found!"
        exit 1
      fi
```

**장점:**
- 자동 취약점 스캔
- Critical 발견 시 배포 중단
- CGV에는 없는 기능

#### 4) CloudWatch Logs 중앙 집중

**buildspec.yml:**
```yaml
phases:
  install:
    commands:
      # CloudWatch Logs Agent 설치
      - wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
      - rpm -U ./amazon-cloudwatch-agent.rpm
  
  build:
    commands:
      # 빌드 로그를 CloudWatch로 전송
      - mvn clean package 2>&1 | tee /tmp/build.log
      - aws logs put-log-events --log-group-name /aws/codebuild/erp-build --log-stream-name $CODEBUILD_BUILD_ID --log-events timestamp=$(date +%s000),message="$(cat /tmp/build.log)"
```

**CloudWatch Insights 쿼리:**
```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)
```

**장점:**
- 모든 빌드 로그 중앙 집중
- 실시간 모니터링
- 알람 설정 가능

#### 5) X-Ray 트레이싱 통합

**buildspec.yml:**
```yaml
post_build:
  commands:
    # X-Ray 세그먼트 시작
    - |
      TRACE_ID=$(aws xray put-trace-segments --trace-segment-documents '[{
        "name": "CodeBuild-Deploy",
        "id": "'$(uuidgen)'",
        "start_time": '$(date +%s)',
        "in_progress": true
      }]' --query 'UnprocessedTraceSegments[0].Id' --output text)
    
    # 배포 실행
    - helm upgrade --install ...
    
    # X-Ray 세그먼트 종료
    - |
      aws xray put-trace-segments --trace-segment-documents '[{
        "name": "CodeBuild-Deploy",
        "id": "'$TRACE_ID'",
        "end_time": '$(date +%s)',
        "http": {
          "response": {
            "status": 200
          }
        }
      }]'
```

**장점:**
- 배포 시간 추적
- 병목 구간 분석
- 서비스 맵 시각화

#### 6) CodeBuild 환경 변수 암호화

**CodeBuild 프로젝트 설정:**
```json
{
  "environment": {
    "environmentVariables": [
      {
        "name": "DB_PASSWORD",
        "value": "arn:aws:secretsmanager:ap-northeast-2:xxx:secret:prod/rds",
        "type": "SECRETS_MANAGER"
      },
      {
        "name": "DOCKER_HUB_TOKEN",
        "value": "/erp/dev/dockerhub/token",
        "type": "PARAMETER_STORE"
      }
    ]
  }
}
```

**장점:**
- buildspec.yml에 Secret 없음
- IAM 권한으로 접근 제어
- 자동 복호화

### 5.3 최종 CI/CD 구조

```
GitHub Push
  ↓
CodePipeline (단일)
  ├─ Source Stage: GitHub (Webhook)
  ├─ Build Stage: CodeBuild
  │   ├─ Secrets Manager에서 Secret 로드
  │   ├─ Parameter Store에서 설정 로드
  │   ├─ 변경된 서비스만 빌드
  │   ├─ ECR 푸시 + 자동 스캔
  │   ├─ 취약점 검사 (Critical 시 중단)
  │   ├─ Helm values 업데이트
  │   ├─ helm upgrade (전체 배포)
  │   ├─ CloudWatch Logs 전송
  │   └─ X-Ray 트레이싱
  └─ Approval Stage: 수동 승인 (운영계만)
  ↓
EKS Rolling Update
  ↓
CloudWatch Alarms (배포 실패 시 알림)
```

---

## 6. 재구축 마스터 플랜

### Phase 0: 준비 (1시간)

**Step 1: Secrets Manager 생성**
```bash
# RDS 비밀번호
aws secretsmanager create-secret \
  --name prod/rds/password \
  --secret-string "123456789" \
  --region ap-northeast-2

# MongoDB URI
aws secretsmanager create-secret \
  --name prod/mongodb/uri \
  --secret-string "mongodb+srv://..." \
  --region ap-northeast-2
```

**Step 2: Parameter Store 생성**
```bash
# ECR Repository
aws ssm put-parameter \
  --name /erp/dev/ecr/repository \
  --value "806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp" \
  --type String

# EKS Cluster
aws ssm put-parameter \
  --name /erp/dev/eks/cluster-name \
  --value "erp-dev" \
  --type String
```

**Step 3: External Secrets Operator 설치**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

**Step 4: 백업**
```bash
kubectl get all -n erp-dev -o yaml > backup-$(date +%Y%m%d).yaml
git tag backup-before-rebuild
```

### Phase 1: Helm Chart 생성 (2시간)

**파일 생성 (다음 메시지에서 제공)**

### Phase 2: buildspec.yml 작성 (2시간)

**CodePipeline 강점 극대화 (다음 메시지에서 제공)**

### Phase 3: CodePipeline 재생성 (1시간)

**단일 파이프라인 + Approval Stage**

### Phase 4: 배포 및 검증 (2시간)

**Helm 배포 + 동작 확인**

### Phase 5: Lambda 전환 (선택, 3시간)

**Employee Service → Lambda**

---

**다음 메시지에서 구체적인 파일 내용을 제공하겠습니다!**
