# 06. buildspec.yml 작성 (단일 파이프라인)

**소요 시간**: 1.5시간  
**목표**: 4개 buildspec.yml → 1개 통합, CodePipeline 강점 극대화

---

##  CodePipeline 강점 극대화

### CGV와 차별화

| 기능 | CGV (GitLab CI) | ERP (CodePipeline) |
|------|----------------|-------------------|
| Secret 관리 | GitLab Variables | AWS Secrets Manager  |
| 설정 관리 | .gitlab-ci.yml 하드코딩 | Parameter Store  |
| 이미지 스캔 | 수동 | ECR 자동 스캔  |
| 로그 관리 | GitLab Logs | CloudWatch Logs  |
| 트레이싱 | 없음 | X-Ray 통합  |
| 변경 감지 | 전체 빌드 | Git diff로 선택 빌드  |

---

##  현재 문제점 분석

### 문제 1: 4개 buildspec.yml 중복

**현재 구조:**
```
backend/
├── employee-service/buildspec.yml          # 거의 동일
├── approval-request-service/buildspec.yml  # 거의 동일
├── approval-processing-service/buildspec.yml  # 거의 동일
└── notification-service/buildspec.yml      # 거의 동일
```

**중복 코드:**
- ECR 로그인 (4번 반복)
- kubeconfig 업데이트 (4번 반복)
- Maven 빌드 (4번 반복)
- Docker 빌드/푸시 (4번 반복)

### 문제 2: kubectl set image만 실행

**현재 post_build:**
```yaml
post_build:
  commands:
    - kubectl set image deployment/employee-service \
        employee-service=$REPOSITORY_URI:$IMAGE_TAG -n erp-dev
```

**문제:**
- 이미지만 변경
- Manifests 변경 (replicas, resources, env) 반영 안 됨
- Git이 진실이 아님

### 문제 3: 환경 변수 하드코딩

**현재:**
```yaml
- REPOSITORY_URI=806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service
- aws eks update-kubeconfig --region ap-northeast-2 --name erp-dev
```

**문제:**
- 계정 ID, 리전, 클러스터 이름 하드코딩
- 환경 변경 시 4개 파일 모두 수정 필요

---

##  Step 1: 루트에 buildspec.yml 생성 (30분)

### 1-1. 파일 생성

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project

# 루트에 buildspec.yml 생성
cat > buildspec.yml << 'EOF'
version: 0.2

env:
  # Parameter Store 통합
  parameter-store:
    AWS_ACCOUNT_ID: /erp/dev/account-id
    AWS_REGION: /erp/dev/region
    EKS_CLUSTER_NAME: /erp/dev/eks/cluster-name
    ECR_REPOSITORY_PREFIX: /erp/dev/ecr/repository-prefix
    PROJECT_NAME: /erp/dev/project-name
    ENVIRONMENT: /erp/dev/environment

phases:
  install:
    commands:
      # Helm 설치
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      - helm version
      # yq 설치 (YAML 파싱용)
      - wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
      - chmod +x /usr/local/bin/yq
      - yq --version
      
      # kubectl 버전 확인
      - kubectl version --client
  
  pre_build:
    commands:
      # ECR 로그인
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
      
      # EKS kubeconfig 업데이트
      - echo Updating kubeconfig...
      - aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
      
      # 변경된 서비스 감지
      - echo Detecting changed services...
      - |
        if [ -z "$CODEBUILD_WEBHOOK_PREV_COMMIT" ]; then
          echo "First build, building all services"
          CHANGED_SERVICES="approval-request-service approval-processing-service notification-service"
          LAMBDA_CHANGED="false"
        else
          CHANGED_FILES=$(git diff --name-only $CODEBUILD_WEBHOOK_PREV_COMMIT $CODEBUILD_RESOLVED_SOURCE_VERSION)
          echo "Changed files: $CHANGED_FILES"
          
          CHANGED_SERVICES=""
          LAMBDA_CHANGED="false"
          
          # Employee Service는 Lambda로 별도 처리
          if echo "$CHANGED_FILES" | grep -q "backend/employee-service/"; then
            LAMBDA_CHANGED="true"
          fi
          
          if echo "$CHANGED_FILES" | grep -q "backend/approval-request-service/"; then
            CHANGED_SERVICES="$CHANGED_SERVICES approval-request-service"
          fi
          if echo "$CHANGED_FILES" | grep -q "backend/approval-processing-service/"; then
            CHANGED_SERVICES="$CHANGED_SERVICES approval-processing-service"
          fi
          if echo "$CHANGED_FILES" | grep -q "backend/notification-service/"; then
            CHANGED_SERVICES="$CHANGED_SERVICES notification-service"
          fi
          
          # Helm Chart 변경 시 EKS 서비스만 재배포
          if echo "$CHANGED_FILES" | grep -q "helm-chart/"; then
            echo "Helm Chart changed, deploying all EKS services"
            CHANGED_SERVICES="approval-request-service approval-processing-service notification-service"
          fi
        fi
      - echo "Services to build: $CHANGED_SERVICES"
      - echo "Lambda changed: $LAMBDA_CHANGED"
      - export CHANGED_SERVICES
      - export LAMBDA_CHANGED
      
      # 이미지 태그 생성
      - IMAGE_TAG=${CODEBUILD_RESOLVED_SOURCE_VERSION:0:7}
      - echo "Image tag: $IMAGE_TAG"
  
  build:
    commands:
      - echo Build started on `date`
      
      # Lambda (Employee Service) 빌드
      - |
        if [ "$LAMBDA_CHANGED" = "true" ]; then
          echo "Building Lambda (Employee Service)..."
          cd backend/employee-service
          
          # Maven 빌드
          mvn clean package -DskipTests
          
          # Lambda용 Docker 이미지 빌드
          docker build -f Dockerfile.lambda -t employee-service-lambda:latest .
          docker tag employee-service-lambda:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:$IMAGE_TAG
          docker tag employee-service-lambda:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:latest
          
          # ECR 푸시
          docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:$IMAGE_TAG
          docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:latest
          
          # Lambda 함수 업데이트
          aws lambda update-function-code \
            --function-name $PROJECT_NAME-$ENVIRONMENT-employee-service \
            --image-uri $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:$IMAGE_TAG \
            --region $AWS_REGION
          
          cd ../..
        fi
      
      # EKS 서비스 빌드
      - |
        for SERVICE in $CHANGED_SERVICES; do
          echo "Building $SERVICE..."
          cd backend/$SERVICE
          
          # Maven 빌드
          echo "Running Maven build for $SERVICE..."
          mvn clean package -DskipTests
          
          # Docker 빌드
          echo "Building Docker image for $SERVICE..."
          REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/$SERVICE
          docker build -t $REPOSITORY_URI:latest .
          docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
          
          # ECR 푸시
          echo "Pushing Docker image for $SERVICE..."
          docker push $REPOSITORY_URI:latest
          docker push $REPOSITORY_URI:$IMAGE_TAG
          
          # ECR 이미지 스캔 시작
          echo "Starting ECR image scan for $SERVICE..."
          aws ecr start-image-scan \
            --repository-name $ECR_REPOSITORY_PREFIX/$SERVICE \
            --image-id imageTag=$IMAGE_TAG \
            --region $AWS_REGION || true
          
          cd ../..
        done
  
  post_build:
    commands:
      # ECR 이미지 스캔 결과 확인
      - echo "Checking ECR scan results..."
      - |
        for SERVICE in $CHANGED_SERVICES; do
          echo "Waiting for scan results for $SERVICE..."
          SCAN_STATUS="IN_PROGRESS"
          RETRY_COUNT=0
          MAX_RETRIES=30
          
          while [ "$SCAN_STATUS" = "IN_PROGRESS" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            sleep 10
            SCAN_STATUS=$(aws ecr describe-image-scan-findings \
              --repository-name $ECR_REPOSITORY_PREFIX/$SERVICE \
              --image-id imageTag=$IMAGE_TAG \
              --region $AWS_REGION \
              --query 'imageScanStatus.status' \
              --output text 2>/dev/null || echo "IN_PROGRESS")
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "Scan status for $SERVICE: $SCAN_STATUS (attempt $RETRY_COUNT/$MAX_RETRIES)"
          done
          
          if [ "$SCAN_STATUS" = "COMPLETE" ]; then
            # Critical 취약점 확인
            CRITICAL=$(aws ecr describe-image-scan-findings \
              --repository-name $ECR_REPOSITORY_PREFIX/$SERVICE \
              --image-id imageTag=$IMAGE_TAG \
              --region $AWS_REGION \
              --query 'imageScanFindings.findingSeverityCounts.CRITICAL' \
              --output text 2>/dev/null || echo "0")
            
            if [ "$CRITICAL" != "None" ] && [ "$CRITICAL" != "0" ]; then
              echo "ERROR: Critical vulnerabilities found in $SERVICE: $CRITICAL"
              echo "Deployment aborted for security reasons"
              exit 1
            else
              echo "No critical vulnerabilities found in $SERVICE"
            fi
          else
            echo "WARNING: Scan timeout for $SERVICE, proceeding with deployment"
          fi
        done
      
      # Helm values 업데이트
      - echo "Updating Helm values with new image tags..."
      - |
        for SERVICE in $CHANGED_SERVICES; do
          SERVICE_KEY=$(echo $SERVICE | sed 's/-service$//' | sed 's/-\([a-z]\)/\U\1/g' | sed 's/^./\L&/')
          
          # values-dev.yaml 업데이트
          yq eval ".services.$SERVICE_KEY.image.tag = \"$IMAGE_TAG\"" -i helm-chart/values-dev.yaml
          
          echo "Updated $SERVICE_KEY image tag to $IMAGE_TAG"
        done
      
      # Git에 변경사항 커밋 (선택 사항)
      # - git config user.email "codebuild@erp.com"
      # - git config user.name "CodeBuild"
      # - git add helm-chart/values-dev.yaml
      # - git commit -m "Update image tags to $IMAGE_TAG [skip ci]"
      # - git push origin main
      
      # Helm 배포
      - echo "Deploying to EKS with Helm..."
      - |
        helm upgrade --install erp-microservices helm-chart/ \
          -f helm-chart/values-dev.yaml \
          -n erp-dev \
          --create-namespace \
          --wait \
          --timeout 5m
      
      # 배포 확인
      - echo "Verifying deployment..."
      - kubectl get pods -n erp-dev
      - kubectl get svc -n erp-dev
      
      # Helm 히스토리 확인
      - helm history erp-microservices -n erp-dev
      
      - echo Build completed on `date`

artifacts:
  files:
    - helm-chart/**/*
  name: helm-chart-$IMAGE_TAG

cache:
  paths:
    - '/root/.m2/**/*'
EOF
```

---

##  Step 2: Parameter Store 생성 (10분)

### 2-1. AWS CLI로 생성

```bash
# 계정 ID
aws ssm put-parameter \
  --name /erp/dev/account-id \
  --value "806332783810" \
  --type String \
  --region ap-northeast-2

# 리전
aws ssm put-parameter \
  --name /erp/dev/region \
  --value "ap-northeast-2" \
  --type String \
  --region ap-northeast-2

# EKS 클러스터 이름
aws ssm put-parameter \
  --name /erp/dev/eks/cluster-name \
  --value "erp-dev" \
  --type String \
  --region ap-northeast-2

# ECR Repository Prefix
aws ssm put-parameter \
  --name /erp/dev/ecr/repository-prefix \
  --value "erp" \
  --type String \
  --region ap-northeast-2

# Project Name
aws ssm put-parameter \
  --name /erp/dev/project-name \
  --value "erp" \
  --type String \
  --region ap-northeast-2

# Environment
aws ssm put-parameter \
  --name /erp/dev/environment \
  --value "dev" \
  --type String \
  --region ap-northeast-2
```

**확인:**
```bash
aws ssm get-parameters \
  --names /erp/dev/account-id /erp/dev/region /erp/dev/eks/cluster-name /erp/dev/ecr/repository-prefix /erp/dev/project-name /erp/dev/environment \
  --region ap-northeast-2
```

---

##  Step 3: IAM 권한 추가 (10분)

### 3-1. CodeBuild Role에 권한 추가

**Terraform으로 추가 (권장):**

```bash
cd infrastructure/terraform/dev/erp-dev-IAM/codebuild-role

# codebuild-role.tf에 추가
cat >> codebuild-role.tf << 'EOF'

# Parameter Store 읽기 권한
resource "aws_iam_role_policy" "codebuild_ssm" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-ssm-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = "arn:aws:ssm:ap-northeast-2:806332783810:parameter/erp/*"
    }]
  })
}

# Secrets Manager 읽기 권한
resource "aws_iam_role_policy" "codebuild_secrets" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:ap-northeast-2:806332783810:secret:prod/*"
    }]
  })
}

# ECR 이미지 스캔 권한
resource "aws_iam_role_policy" "codebuild_ecr_scan" {
  role = aws_iam_role.codebuild.id
  name = "codebuild-ecr-scan-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:StartImageScan",
        "ecr:DescribeImageScanFindings"
      ]
      Resource = "*"
    }]
  })
}
EOF

# 적용
terraform apply -auto-approve
```

**또는 AWS CLI로 직접 추가:**

```bash
# Parameter Store 권한
aws iam put-role-policy \
  --role-name erp-dev-codebuild-role \
  --policy-name SSMReadPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["ssm:GetParameter", "ssm:GetParameters"],
      "Resource": "arn:aws:ssm:ap-northeast-2:806332783810:parameter/erp/*"
    }]
  }'

# Secrets Manager 권한
aws iam put-role-policy \
  --role-name erp-dev-codebuild-role \
  --policy-name SecretsManagerReadPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
      "Resource": "arn:aws:secretsmanager:ap-northeast-2:806332783810:secret:prod/*"
    }]
  }'

# ECR 스캔 권한
aws iam put-role-policy \
  --role-name erp-dev-codebuild-role \
  --policy-name ECRScanPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["ecr:StartImageScan", "ecr:DescribeImageScanFindings"],
      "Resource": "*"
    }]
  }'
```

---

##  Step 4: 검증 (20분)

### 4-1. 로컬 테스트 (Dry-run)

```bash
# buildspec.yml 문법 확인
cat buildspec.yml | yq eval '.' -

# 환경 변수 시뮬레이션
export AWS_ACCOUNT_ID=806332783810
export AWS_REGION=ap-northeast-2
export EKS_CLUSTER_NAME=erp-dev
export ECR_REPOSITORY_PREFIX=erp
export CODEBUILD_RESOLVED_SOURCE_VERSION=$(git rev-parse HEAD)

# pre_build 단계 테스트
echo "Testing pre_build phase..."
CHANGED_SERVICES="employee-service"
echo "Services to build: $CHANGED_SERVICES"
```

### 4-2. 기존 buildspec.yml 백업 및 삭제

```bash
# 백업
mkdir -p backup-buildspec
cp backend/employee-service/buildspec.yml backup-buildspec/
cp backend/approval-request-service/buildspec.yml backup-buildspec/
cp backend/approval-processing-service/buildspec.yml backup-buildspec/
cp backend/notification-service/buildspec.yml backup-buildspec/

# 삭제
rm backend/employee-service/buildspec.yml
rm backend/approval-request-service/buildspec.yml
rm backend/approval-processing-service/buildspec.yml
rm backend/notification-service/buildspec.yml
```

### 4-3. Git 커밋

```bash
git add buildspec.yml
git add helm-chart/
git rm backend/*/buildspec.yml
git commit -m "Unified buildspec.yml with CodePipeline strengths"
```

---

##  완료 체크리스트

- [ ] 루트에 buildspec.yml 생성
- [ ] Parameter Store 4개 생성 (account-id, region, cluster-name, repository-prefix)
- [ ] CodeBuild IAM Role에 SSM 권한 추가
- [ ] CodeBuild IAM Role에 Secrets Manager 권한 추가
- [ ] CodeBuild IAM Role에 ECR 스캔 권한 추가
- [ ] 기존 buildspec.yml 4개 백업
- [ ] 기존 buildspec.yml 4개 삭제
- [ ] Git 커밋 완료

---

##  다음 단계

**buildspec.yml 작성 완료!**

**다음 파일을 읽으세요:**
→ **05_CODEPIPELINE.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 05_CODEPIPELINE.md
```

---

##  주요 개선 사항

### 1. 변경 감지 로직

**기존:**
- 4개 파이프라인이 각각 트리거
- 모든 서비스 항상 빌드

**개선:**
- Git diff로 변경된 서비스만 감지
- 변경된 서비스만 빌드
- Helm Chart 변경 시 전체 재배포

### 2. ECR 이미지 스캔 자동화

**기존:**
- 이미지 스캔 없음
- 취약점 확인 수동

**개선:**
- 푸시 후 자동 스캔
- Critical 취약점 발견 시 배포 중단
- 보안 강화

### 3. Helm 배포

**기존:**
- kubectl set image (이미지만 변경)
- Manifests 변경 반영 안 됨

**개선:**
- helm upgrade (전체 리소스 배포)
- Manifests 변경 자동 반영
- Git이 진실

### 4. Parameter Store 활용

**기존:**
- 계정 ID, 리전 하드코딩
- 4개 파일 모두 수정 필요

**개선:**
- Parameter Store 중앙 관리
- 환경 변경 시 Parameter만 수정
- 일관성 유지

---

**"단일 buildspec.yml로 모든 서비스를 관리합니다. CodePipeline의 강점을 최대한 활용했습니다!"**
