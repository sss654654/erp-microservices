# 07. CodePipeline 생성 (단일 파이프라인 + 완전 자동화)

**소요 시간**: 1시간  
**목표**: 4개 CodePipeline → 1개 통합, Git Push 한 번으로 전체 배포 자동화

---

## 🎯 01-06 단계의 의미: AWS Native CI/CD 인프라 준비

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   01-06: 인프라 준비 (수동, 한 번만)                          │
│                                                                             │
│  01. Secrets Manager    → RDS 비밀번호 저장 (Git에 노출 방지)               │
│  02. Terraform          → VPC, EKS, RDS, Lambda, API Gateway 생성           │
│  03. Image Build        → 초기 이미지 ECR 푸시 (최초 1회)                   │
│  04. Lambda Deploy      → Lambda 함수 생성 (최초 1회)                       │
│  05. Helm Chart         → Kubernetes 배포 템플릿 작성                       │
│  06. Monitoring         → CloudWatch Logs, X-Ray, Alarm 설정                │
│                                                                             │
│  ✅ 결과: AWS 인프라 + 모니터링 완성 (CodePipeline이 사용할 환경 준비)       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│              07: CodePipeline 구축 (자동화 시작!)                            │
│                                                                             │
│  CodePipeline + CodeBuild 생성 (AWS Console 클릭 몇 번)                     │
│  → buildspec.yml이 01-06에서 만든 모든 것을 자동으로 사용                    │
│                                                                             │
│  ✅ 결과: Git Push 한 번 → 빌드 → 배포 → 모니터링 (완전 자동화)              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📐 AWS Native CI/CD 아키텍처 (간단 버전)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        🚀 AWS Native CI/CD 흐름                              │
│                    (CodePipeline + CodeBuild 중심)                          │
└─────────────────────────────────────────────────────────────────────────────┘

Developer (로컬)
    │
    │ git push origin main
    ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│  GitHub Repository                                                           │
│  └── Webhook 자동 트리거                                                      │
└──────────────────────────────────────────────────────────────────────────────┘
    │
    ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│  🔵 CodePipeline (오케스트레이션)                                             │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ Stage 1: Source (GitHub에서 코드 가져오기)                              │ │
│  │ Stage 2: Build (CodeBuild 실행)                                        │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  💡 CodePipeline의 역할:                                                     │
│     - GitHub Webhook 자동 감지                                              │
│     - CodeBuild 자동 실행                                                   │
│     - 실패 시 알림 (SNS)                                                    │
│     - 배포 히스토리 관리                                                     │
└──────────────────────────────────────────────────────────────────────────────┘
    │
    ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│  🔨 CodeBuild (실제 작업 수행)                                                │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ buildspec.yml 실행 (01-06에서 준비한 인프라 사용)                       │ │
│  │                                                                         │ │
│  │ 1️⃣ Parameter Store 읽기 (02단계에서 생성)                               │ │
│  │    └── Account ID, Region, EKS Cluster Name 등                        │ │
│  │                                                                         │ │
│  │ 2️⃣ Git diff로 변경 감지                                                 │ │
│  │    └── 변경된 서비스만 빌드 (시간 절약)                                 │ │
│  │                                                                         │ │
│  │ 3️⃣ Maven 빌드 + Docker 빌드                                             │ │
│  │    └── ECR 푸시 (02단계에서 생성한 Repository)                         │ │
│  │                                                                         │ │
│  │ 4️⃣ ECR 이미지 스캔                                                       │ │
│  │    └── CRITICAL 취약점 발견 시 배포 중단                                │ │
│  │                                                                         │ │
│  │ 5️⃣ Lambda 함수 업데이트 (04단계에서 생성)                               │ │
│  │    └── aws lambda update-function-code                                │ │
│  │                                                                         │ │
│  │ 6️⃣ Helm Chart values 업데이트 (05단계에서 생성)                         │ │
│  │    └── yq로 이미지 태그 변경                                            │ │
│  │                                                                         │ │
│  │ 7️⃣ Helm 배포 (05단계 템플릿 사용)                                        │ │
│  │    └── helm upgrade --install                                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  💡 CodeBuild의 역할:                                                        │
│     - 01-06에서 만든 모든 인프라 자동 사용                                   │
│     - IAM Role로 권한 자동 획득 (02단계에서 생성)                            │
│     - CloudWatch Logs 자동 전송 (06단계 설정)                               │
│     - 변경된 서비스만 빌드 (효율성)                                          │
└──────────────────────────────────────────────────────────────────────────────┘
    │
    ↓
┌──────────────────────────────────────────────────────────────────────────────┐
│  ☁️ AWS 인프라 (01-06에서 생성, CodeBuild가 자동 사용)                        │
│                                                                              │
│  🔐 Secrets Manager (01단계)                                                 │
│     └── RDS 비밀번호 저장 → Lambda 환경변수로 자동 주입                      │
│                                                                              │
│  📦 ECR (02단계)                                                              │
│     └── 이미지 저장 → CodeBuild가 자동 푸시                                  │
│                                                                              │
│  ⚡ Lambda (04단계)                                                           │
│     └── Employee Service → CodeBuild가 자동 업데이트                         │
│                                                                              │
│  ⎈ EKS (02단계)                                                               │
│     └── 3개 서비스 → CodeBuild가 Helm으로 자동 배포                          │
│                                                                              │
│  📊 CloudWatch (06단계)                                                       │
│     ├── Logs: Fluent Bit이 자동 수집                                        │
│     ├── X-Ray: HTTP 요청 자동 추적                                           │
│     └── Alarm: ERROR 발생 시 자동 이메일                                     │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  ✅ 최종 결과: Git Push 한 번으로 모든 것이 자동화!                            │
│                                                                              │
│  Git Push → CodePipeline 감지 → CodeBuild 실행                               │
│  → 변경 감지 → 빌드 → 스캔 → 배포 → 모니터링                                 │
│                                                                              │
│  🎯 AWS Native CI/CD의 강점:                                                 │
│     ✅ IAM 통합: 권한 자동 관리                                               │
│     ✅ CloudWatch 통합: 로그/메트릭 자동 수집                                 │
│     ✅ X-Ray 통합: 트레이싱 자동 연동                                         │
│     ✅ Parameter Store 통합: 설정 중앙 관리                                  │
│     ✅ Secrets Manager 통합: 비밀번호 안전 관리                               │
│     ✅ ECR 스캔 통합: 취약점 자동 차단                                        │
│     ✅ 간단한 설정: AWS Console 클릭 몇 번                                    │
│     ✅ 낮은 학습 곡선: AWS 문서만 참고                                        │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 💡 핵심 이해

### 01-06 단계 = 인프라 준비 (수동, 한 번만)
- Terraform으로 AWS 리소스 생성
- Helm Chart 작성
- 모니터링 설정
- **목적**: CodePipeline이 사용할 환경 준비

### 07 단계 = 자동화 시작 (CodePipeline 구축)
- AWS Console에서 CodePipeline + CodeBuild 생성 (클릭 몇 번)
- buildspec.yml이 01-06의 모든 것을 자동으로 사용
- **결과**: Git Push 한 번으로 빌드 → 배포 → 모니터링 완전 자동화

### CodePipeline vs CodeBuild 역할

| 도구 | 역할 | 비유 |
|------|------|------|
| **CodePipeline** | 오케스트레이션 (흐름 제어) | 지휘자 (언제, 무엇을 실행할지 결정) |
| **CodeBuild** | 실제 작업 수행 | 연주자 (빌드, 배포 실제 실행) |

**예시**:
- CodePipeline: "GitHub에 변경 감지됨 → CodeBuild 실행해!"
- CodeBuild: "알겠습니다! buildspec.yml 실행 → 빌드 → 배포 완료!"

---

## 📐 CI/CD 아키텍처 (ERP 프로젝트 - 00~07 통합)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    🔄 CI/CD FLOW                                        │
│                         (Git Push → 자동 빌드 → 자동 배포 → 모니터링)                    │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│  Developer   │
│   (로컬 PC)   │
└──────┬───────┘
       │ git push origin main
       ↓
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              📦 SOURCE (GitHub)                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │ Repository: sss654654/erp-microservices                                            │ │
│  │ Branch: main                                                                       │ │
│  │                                                                                    │ │
│  │ 구조:                                                                               │ │
│  │ ├── backend/                                                                       │ │
│  │ │   ├── approval-request-service/     (EKS)                                       │ │
│  │ │   ├── approval-processing-service/  (EKS)                                       │ │
│  │ │   ├── notification-service/         (EKS)                                       │ │
│  │ │   └── employee-service/             (Lambda) ← 04단계에서 Lambda 전환           │ │
│  │ ├── helm-chart/                       (05단계에서 생성)                            │ │
│  │ │   ├── Chart.yaml                                                                │ │
│  │ │   ├── values-dev.yaml                                                           │ │
│  │ │   └── templates/                                                                │ │
│  │ │       ├── deployment.yaml           (3개 EKS 서비스 통합)                       │ │
│  │ │       ├── service.yaml                                                          │ │
│  │ │       ├── hpa.yaml                                                              │ │
│  │ │       ├── targetgroupbinding.yaml                                               │ │
│  │ │       ├── kafka.yaml                                                            │ │
│  │ │       ├── externalsecret.yaml       (01단계 ASM 연동)                           │ │
│  │ │       ├── secretstore.yaml                                                      │ │
│  │ │       ├── fluent-bit.yaml           (06단계 CloudWatch Logs)                    │ │
│  │ │       └── xray-daemonset.yaml       (06단계 X-Ray)                              │ │
│  │ └── buildspec.yml                     (루트, 이 파일이 모든 것을 제어)             │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────┘
       │
       │ GitHub Webhook (자동 트리거)
       ↓
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                         🚀 CODEPIPELINE (erp-unified-pipeline)                           │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │ Stage 1: Source                                                                    │ │
│  │ ├── GitHub (Version 2) Connection                                                 │ │
│  │ ├── Repository: sss654654/erp-microservices                                       │ │
│  │ ├── Branch: main                                                                  │ │
│  │ └── Output: SourceArtifact (전체 코드)                                             │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│       │
│       ↓
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │ Stage 2: Build (CodeBuild: erp-unified-build)                                     │ │
│  │ ├── Input: SourceArtifact                                                         │ │
│  │ ├── Buildspec: buildspec.yml (루트)                                               │ │
│  │ ├── Environment: Amazon Linux, Docker, Privileged Mode                            │ │
│  │ └── Service Role: erp-dev-codebuild-role (02단계에서 생성, 권한 8개)              │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────┘
       │
       ↓
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                          🔨 CODEBUILD (buildspec.yml 실행)                               │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Phase 1: INSTALL (도구 설치)                                                     │   │
│  │ ├── Helm 3 설치                                                                  │   │
│  │ ├── yq 설치 (YAML 파싱)                                                          │   │
│  │ └── kubectl 확인                                                                 │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│       │
│       ↓
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Phase 2: PRE_BUILD (준비 + 변경 감지)                                            │   │
│  │                                                                                   │   │
│  │ 1️⃣ Parameter Store 읽기 (02단계 12번에서 생성)                                   │   │
│  │    ├── /erp/dev/account-id         → AWS_ACCOUNT_ID                             │   │
│  │    ├── /erp/dev/region              → AWS_REGION                                │   │
│  │    ├── /erp/dev/eks/cluster-name    → EKS_CLUSTER_NAME                          │   │
│  │    ├── /erp/dev/ecr/repository-prefix → ECR_REPOSITORY_PREFIX                   │   │
│  │    ├── /erp/dev/project-name        → PROJECT_NAME                              │   │
│  │    └── /erp/dev/environment         → ENVIRONMENT                               │   │
│  │                                                                                   │   │
│  │ 2️⃣ ECR 로그인                                                                     │   │
│  │    └── aws ecr get-login-password | docker login                                │   │
│  │                                                                                   │   │
│  │ 3️⃣ EKS kubeconfig 업데이트                                                        │   │
│  │    └── aws eks update-kubeconfig --name erp-dev                                 │   │
│  │                                                                                   │   │
│  │ 4️⃣ 이미지 태그 생성                                                               │   │
│  │    └── IMAGE_TAG=${CODEBUILD_RESOLVED_SOURCE_VERSION:0:7}  (Git 커밋 해시 7자리)│   │
│  │                                                                                   │   │
│  │ 5️⃣ Git diff로 변경 감지 (핵심!)                                                   │   │
│  │    ├── git diff --name-only $PREV_COMMIT $CURRENT_COMMIT                        │   │
│  │    ├── backend/employee-service/ 변경 → LAMBDA_CHANGED=true                     │   │
│  │    ├── backend/approval-request-service/ 변경 → CHANGED_SERVICES에 추가         │   │
│  │    ├── backend/approval-processing-service/ 변경 → CHANGED_SERVICES에 추가      │   │
│  │    ├── backend/notification-service/ 변경 → CHANGED_SERVICES에 추가             │   │
│  │    └── helm-chart/ 변경 → HELM_CHANGED=true (모든 EKS 서비스 재배포)            │   │
│  │                                                                                   │   │
│  │ 결과 예시:                                                                        │   │
│  │    CHANGED_SERVICES="approval-request-service"                                   │   │
│  │    LAMBDA_CHANGED="false"                                                        │   │
│  │    HELM_CHANGED="false"                                                          │   │
│  │    IMAGE_TAG="a1b2c3d"                                                           │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│       │
│       ↓
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Phase 3: BUILD (이미지 빌드 + ECR 푸시)                                           │   │
│  │                                                                                   │   │
│  │ 🔹 Lambda (Employee Service) - LAMBDA_CHANGED=true인 경우만                      │   │
│  │    ├── cd backend/employee-service                                               │   │
│  │    ├── mvn clean package -DskipTests                                            │   │
│  │    ├── docker build -f Dockerfile.lambda -t xxx/employee-service-lambda:$TAG    │   │
│  │    ├── docker push xxx/employee-service-lambda:latest                           │   │
│  │    ├── docker push xxx/employee-service-lambda:$IMAGE_TAG                       │   │
│  │    └── aws ecr start-image-scan (취약점 스캔 시작)                               │   │
│  │                                                                                   │   │
│  │ 🔹 EKS 서비스 (3개) - CHANGED_SERVICES에 포함된 것만                             │   │
│  │    for SERVICE in $CHANGED_SERVICES; do                                         │   │
│  │      ├── cd backend/$SERVICE                                                     │   │
│  │      ├── mvn clean package -DskipTests                                          │   │
│  │      ├── docker build -t xxx/$SERVICE:$TAG                                      │   │
│  │      ├── docker push xxx/$SERVICE:latest                                        │   │
│  │      ├── docker push xxx/$SERVICE:$IMAGE_TAG                                    │   │
│  │      └── aws ecr start-image-scan                                               │   │
│  │    done                                                                          │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│       │
│       ↓
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Phase 4: POST_BUILD (스캔 확인 + 배포)                                            │   │
│  │                                                                                   │   │
│  │ 1️⃣ ECR 이미지 스캔 결과 확인 (최대 5분 대기)                                      │   │
│  │    ├── Lambda: employee-service-lambda                                           │   │
│  │    ├── EKS: approval-request-service, approval-processing-service, notification │   │
│  │    ├── CRITICAL 취약점 발견 시 → 배포 중단 (exit 1)                              │   │
│  │    └── 취약점 없으면 → 배포 진행                                                 │   │
│  │                                                                                   │   │
│  │ 2️⃣ Lambda 함수 업데이트 (LAMBDA_CHANGED=true인 경우)                             │   │
│  │    └── aws lambda update-function-code \                                        │   │
│  │          --function-name erp-dev-employee-service \                             │   │
│  │          --image-uri xxx/employee-service-lambda:$IMAGE_TAG                     │   │
│  │                                                                                   │   │
│  │ 3️⃣ Helm Chart values 업데이트 (CHANGED_SERVICES가 있는 경우)                     │   │
│  │    ├── yq eval ".services.approvalRequest.image.tag = \"$IMAGE_TAG\"" \         │   │
│  │    │     -i helm-chart/values-dev.yaml                                          │   │
│  │    ├── yq eval ".services.approvalProcessing.image.tag = \"$IMAGE_TAG\"" \      │   │
│  │    │     -i helm-chart/values-dev.yaml                                          │   │
│  │    └── yq eval ".services.notification.image.tag = \"$IMAGE_TAG\"" \            │   │
│  │          -i helm-chart/values-dev.yaml                                          │   │
│  │                                                                                   │   │
│  │ 4️⃣ Helm 배포 (CHANGED_SERVICES 또는 HELM_CHANGED=true인 경우)                    │   │
│  │    └── helm upgrade erp-dev ./helm-chart \                                      │   │
│  │          --values ./helm-chart/values-dev.yaml \                                │   │
│  │          --namespace erp-dev \                                                   │   │
│  │          --install \                                                             │   │
│  │          --wait \                                                                │   │
│  │          --timeout 5m                                                            │   │
│  │                                                                                   │   │
│  │ 5️⃣ 배포 상태 확인                                                                 │   │
│  │    ├── kubectl get pods -n erp-dev                                              │   │
│  │    └── kubectl get svc -n erp-dev                                               │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────────────┘
       │
       ↓
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                            ☁️ AWS 인프라 (02단계에서 생성)                               │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ 🗄️ ECR (Elastic Container Registry)                                             │   │
│  │ ├── erp/employee-service-lambda:latest, :a1b2c3d                                │   │
│  │ ├── erp/approval-request-service:latest, :a1b2c3d                               │   │
│  │ ├── erp/approval-processing-service:latest, :a1b2c3d                            │   │
│  │ └── erp/notification-service:latest, :a1b2c3d                                   │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│       │
│       ↓
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ ⚡ Lambda (04단계에서 생성)                                                       │   │
│  │ ├── Function: erp-dev-employee-service                                           │   │
│  │ ├── Image: xxx/employee-service-lambda:a1b2c3d                                  │   │
│  │ ├── Environment Variables:                                                       │   │
│  │ │   ├── SPRING_DATASOURCE_URL (RDS 엔드포인트)                                  │   │
│  │ │   ├── SPRING_DATASOURCE_USERNAME (ASM에서 읽음, 01단계)                       │   │
│  │ │   ├── SPRING_DATASOURCE_PASSWORD (ASM에서 읽음, 01단계)                       │   │
│  │ │   └── AWS_LWA_PORT=8081 (Lambda Web Adapter)                                 │   │
│  │ ├── VPC: Private Subnet (RDS 직접 연결)                                         │   │
│  │ ├── X-Ray: Active (06단계에서 활성화)                                            │   │
│  │ └── IAM Role: AWSXRayDaemonWriteAccess (06단계에서 추가)                        │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│       │
│       ↓
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ ⎈ EKS Cluster (02단계에서 생성)                                                  │   │
│  │ ├── Cluster: erp-dev (v1.31)                                                    │   │
│  │ ├── Nodes: 4개 (t3.small)                                                       │   │
│  │ │   ├── 서비스 Node 2개 (ap-northeast-2a, 2c)                                   │   │
│  │ │   └── Kafka Node 2개 (ap-northeast-2a, 2c, Taint로 격리)                     │   │
│  │ │                                                                                │   │
│  │ └── Namespace: erp-dev                                                           │   │
│  │     ├── Pods (12개):                                                             │   │
│  │     │   ├── approval-request-service x2                                         │   │
│  │     │   ├── approval-processing-service x2                                      │   │
│  │     │   ├── notification-service x2                                             │   │
│  │     │   ├── kafka x2                                                             │   │
│  │     │   ├── zookeeper x2                                                         │   │
│  │     │   └── xray-daemon x2 (DaemonSet, 06단계)                                  │   │
│  │     │                                                                            │   │
│  │     ├── Services (6개):                                                          │   │
│  │     │   ├── approval-request-service (ClusterIP:8082)                           │   │
│  │     │   ├── approval-processing-service (ClusterIP:8083)                        │   │
│  │     │   ├── notification-service (ClusterIP:8084)                               │   │
│  │     │   ├── kafka (ClusterIP:9092)                                              │   │
│  │     │   ├── zookeeper (ClusterIP:2181)                                          │   │
│  │     │   └── xray-daemon (ClusterIP UDP:2000)                                    │   │
│  │     │                                                                            │   │
│  │     ├── HPA (3개): CPU 70% 기준 Auto Scaling                                    │   │
│  │     ├── TargetGroupBinding (3개): NLB 연결                                      │   │
│  │     ├── ExternalSecret (1개): ASM → Kubernetes Secret 동기화 (01단계)           │   │
│  │     └── ClusterSecretStore (1개): ASM 연동 설정                                 │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│       │
│       ↓
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ 🌐 API Gateway (02단계에서 생성)                                                 │   │
│  │ ├── Type: HTTP API                                                               │   │
│  │ ├── URL: https://yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com           │   │
│  │ ├── Routes:                                                                      │   │
│  │ │   ├── /api/employees → Lambda (직접 통합, 04단계)                             │   │
│  │ │   ├── /api/approvals → NLB → approval-request-service                        │   │
│  │ │   ├── /api/processing → NLB → approval-processing-service                    │   │
│  │ │   └── /api/notifications → NLB → notification-service                        │   │
│  │ └── VPC Link: NLB 연결 (EKS 서비스용)                                           │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────────────┘
       │
       ↓
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                          📊 모니터링 (06단계에서 구축)                                    │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ 📝 CloudWatch Logs (Fluent Bit DaemonSet)                                       │   │
│  │ ├── Namespace: amazon-cloudwatch                                                 │   │
│  │ ├── Pods: fluent-bit x2 (DaemonSet, 각 노드에 1개)                              │   │
│  │ ├── Log Group: /aws/eks/erp-dev/application                                     │   │
│  │ └── 수집 대상:                                                                    │   │
│  │     ├── approval-request-service 로그                                           │   │
│  │     ├── approval-processing-service 로그                                        │   │
│  │     ├── notification-service 로그                                               │   │
│  │     └── kafka, zookeeper 로그                                                    │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│       │
│       ↓
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ 🔍 X-Ray 트레이싱                                                                 │   │
│  │ ├── X-Ray Daemon: xray-daemon x2 (DaemonSet)                                    │   │
│  │ ├── 추적 대상:                                                                    │   │
│  │ │   ├── ✅ approval-request-service (HTTP, Servlet Filter)                      │   │
│  │ │   ├── ✅ employee-service Lambda (Lambda 내장 X-Ray)                          │   │
│  │ │   ├── ❌ approval-processing-service (Kafka Consumer, HTTP 없음)              │   │
│  │ │   └── ❌ notification-service (내부 서비스, 외부 HTTP 없음)                    │   │
│  │ └── 환경변수: AWS_XRAY_DAEMON_ADDRESS=xray-daemon.erp-dev.svc.cluster.local:2000│   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│       │
│       ↓
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ 🚨 CloudWatch Alarm (SNS 이메일 알림)                                            │   │
│  │ ├── SNS Topic: erp-dev-alarms                                                    │   │
│  │ ├── Email: subinhong0109@dankook.ac.kr (Confirmed)                              │   │
│  │ ├── Alarm 3개:                                                                   │   │
│  │ │   ├── erp-dev-high-error-rate (ERROR 로그 10회 이상, 5분)                     │   │
│  │ │   ├── erp-dev-pod-restarts (Pod 재시작 3회 이상, 10분)                        │   │
│  │ │   └── erp-dev-lambda-error-rate (Lambda 에러율 5% 이상)                       │   │
│  │ └── Metric Filter:                                                               │   │
│  │     ├── ERROR 패턴 감지 → ErrorCount 메트릭                                     │   │
│  │     └── Pod 재시작 감지 → PodRestartCount 메트릭                                │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                          ✅ 배포 완료 (Git이 진실)                                        │
│                                                                                          │
│  Git Push → CodePipeline 자동 트리거 → 변경 감지 → 빌드 → 스캔 → 배포 → 모니터링       │
│                                                                                          │
│  - 변경된 서비스만 빌드 (시간 절약)                                                      │
│  - ECR 스캔으로 취약점 차단 (보안)                                                       │
│  - Helm으로 전체 리소스 배포 (Manifests 반영)                                           │
│  - CloudWatch Logs로 중앙 집중 (영구 보관)                                              │
│  - X-Ray로 분산 추적 (성능 분석)                                                         │
│  - CloudWatch Alarm으로 실시간 알림 (장애 대응)                                         │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📐 CI/CD 아키텍처 비교 (ERP vs CGV)

### 🔵 CGV 프로젝트 CI/CD (개발계 중심)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                          CGV 개발계 CI/CD (GitLab + ArgoCD)                             │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│  Developer   │
└──────┬───────┘
       │ git push
       ↓
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              📦 SOURCE (GitLab - 자체 호스팅)                             │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │ GitLab EC2 (Private Subnet)                                                        │ │
│  │ ├── 접근: Client VPN (개발자만)                                                     │ │
│  │ ├── 보안: 외부 노출 최소화                                                          │ │
│  │ └── 백업: AWS Backup (3시간 주기)                                                   │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────┘
       │
       │ GitLab Webhook
       ↓
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              🔨 CI (GitLab Runner)                                       │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │ 1️⃣ CI 트리거 (Commit & Push)                                                        │ │
│  │    └── GitLab Runner 실행                                                           │ │
│  │                                                                                     │ │
│  │ 2️⃣ 정적 테스트 (SonarQube)                                                          │ │
│  │    ├── 코드 스멜 분석                                                                │ │
│  │    ├── 코드 품질 검사                                                                │ │
│  │    └── 기술 부채 측정                                                                │ │
│  │                                                                                     │ │
│  │ 3️⃣ 보안 검사 (Dependency Check)                                                     │ │
│  │    ├── 의존성 취약점 스캔                                                            │ │
│  │    └── CVE 데이터베이스 대조                                                         │ │
│  │                                                                                     │ │
│  │ 4️⃣ Docker Build                                                                     │ │
│  │    └── Spring Boot 애플리케이션 이미지 빌드                                          │ │
│  │                                                                                     │ │
│  │ 5️⃣ ECR Push (PrivateLink 경유)                                                      │ │
│  │    ├── VPC Endpoints를 통한 보안 전송                                               │ │
│  │    └── 외부 인터넷 노출 없음                                                         │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────┘
       │
       ↓
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              🐙 CD (ArgoCD - GitOps)                                     │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ 🔹 모든 환경 (Prod/QA) - Pull 방식                                                │   │
│  │    ┌──────────┐                                                                  │   │
│  │    │ GitLab   │                                                                  │   │
│  │    │(Manifest)│                                                                  │   │
│  │    └────┬─────┘                                                                  │   │
│  │         │ 수동 sync 요청                                                          │   │
│  │         ↓                                                                        │   │
│  │    ┌──────────┐         Sync          ┌────────────────┐                        │   │
│  │    │ Argo CD  │ ──────────────────→   │  Kubernetes    │                        │   │
│  │    │          │ ←──────────────────   │  Resources     │                        │   │
│  │    └──────────┘         Pull          └────────────────┘                        │   │
│  │         ↓                                                                        │   │
│  │    ┌──────────┐                                                                  │   │
│  │    │   ECR    │                                                                  │   │
│  │    └──────────┘                                                                  │   │
│  │                                                                                   │   │
│  │ 특징:                                                                             │   │
│  │ - Git이 진실 (Source of Truth)                                                   │   │
│  │ - Drift Detection (Git ↔ Cluster 비교)                                          │   │
│  │ - 수동 승인 후 배포 (운영 안정성)                                                 │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│       │
│       ↓
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ 🔹 개발계 (Dev) - Image Updater (자동 배포)                                       │   │
│  │    ┌──────────┐                                                                  │   │
│  │    │   ECR    │                                                                  │   │
│  │    └────┬─────┘                                                                  │   │
│  │         │ 새 태그 감지                                                            │   │
│  │         ↓                                                                        │   │
│  │    ┌──────────────┐                                                              │   │
│  │    │ImageUpdater  │                                                              │   │
│  │    └────┬─────────┘                                                              │   │
│  │         │ 변경 알림                                                               │   │
│  │         ↓                                                                        │   │
│  │    ┌──────────┐         Sync          ┌────────────────┐                        │   │
│  │    │ Argo CD  │ ──────────────────→   │  Kubernetes    │                        │   │
│  │    │          │ ←──────────────────   │  Resources     │                        │   │
│  │    └──────────┘         Pull          └────────────────┘                        │   │
│  │                                                                                   │   │
│  │ 특징:                                                                             │   │
│  │ - ECR 새 태그 자동 감지                                                           │   │
│  │ - GitLab values.yaml 자동 업데이트                                               │   │
│  │ - ArgoCD 자동 Sync                                                               │   │
│  │ - 빈번한 배포 지원 (개발 속도 향상)                                               │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────────────┘
       │
       ↓
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                          📊 모니터링 (Datadog + CloudWatch)                              │
│  ┌────────────────────────────────────────────────────────────────────────────────┐    │
│  │ Datadog                                                                         │    │
│  │ ├── EKS 내부 자원 (Pod, Node) 모니터링                                          │    │
│  │ ├── Slack 실시간 알림                                                            │    │
│  │ └── DR Route53 Health Check 실패 감지                                           │    │
│  │                                                                                  │    │
│  │ CloudWatch                                                                       │    │
│  │ ├── AWS 인프라 상태 모니터링                                                     │    │
│  │ └── EventBridge 트리거 (DR 자동 복구)                                           │    │
│  └────────────────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 ERP vs CGV 상세 비교

### 1️⃣ CI/CD 도구

| 항목 | ERP (개인 프로젝트) | CGV (CloudWave 팀플) |
|------|-------------------|---------------------|
| **Source** | GitHub (Public) | GitLab (자체 호스팅, Private) |
| **CI 도구** | CodeBuild | GitLab Runner |
| **CD 도구** | CodePipeline (Push) | ArgoCD (Pull, GitOps) |
| **빌드 트리거** | GitHub Webhook | GitLab Webhook |
| **배포 방식** | buildspec.yml에서 helm upgrade | ArgoCD가 Git 감시 후 자동 Sync |

**ERP 장점**:
- ✅ AWS 네이티브 (CodePipeline, CodeBuild)
- ✅ 설정 간단 (AWS Console에서 클릭)
- ✅ IAM 통합 (권한 관리 용이)
- ✅ CloudWatch Logs 자동 연동

**CGV 장점**:
- ✅ GitOps (Git이 진실, Drift Detection)
- ✅ 보안 강화 (GitLab 자체 호스팅, 외부 노출 최소화)
- ✅ 코드 품질 검사 (SonarQube, Dependency Check)
- ✅ 롤백 용이 (ArgoCD UI에서 클릭)
- ✅ Image Updater (개발계 자동 배포)

---

### 2️⃣ 변경 감지

| 항목 | ERP | CGV |
|------|-----|-----|
| **방식** | Git diff (buildspec.yml) | ArgoCD 자동 감지 |
| **정확도** | 높음 (파일 경로 기반) | 매우 높음 (Git Commit 기반) |
| **배포 대상** | 변경된 서비스만 | 변경된 Manifest만 |

**ERP 방식**:
```bash
# buildspec.yml pre_build 단계
git diff --name-only $PREV_COMMIT $CURRENT_COMMIT
→ backend/approval-request-service/ 변경 감지
→ CHANGED_SERVICES="approval-request-service"
→ 해당 서비스만 빌드
```

**CGV 방식**:
```
ArgoCD가 GitLab 저장소 주기적 폴링
→ Manifest 변경 감지
→ Kubernetes 리소스와 비교 (Drift Detection)
→ Sync 실행 (변경된 리소스만)
```

**비교**:
- ERP: 빌드 시점에 변경 감지 (빠름)
- CGV: 배포 시점에 변경 감지 (정확함)

---

### 3️⃣ 보안

| 항목 | ERP | CGV |
|------|-----|-----|
| **Source 보안** | GitHub (Public) | GitLab (Private, VPN 접근) |
| **CI 보안** | CodeBuild (AWS 관리) | GitLab Runner (자체 관리) |
| **코드 품질** | 없음 | SonarQube (코드 스멜) |
| **취약점 스캔** | ECR 스캔 (CRITICAL 차단) | Dependency Check + ECR 스캔 |
| **Secret 관리** | ASM + External Secrets | Secret Manager |
| **네트워크** | Public (Internet Gateway) | Private (VPC Endpoints, PrivateLink) |

**ERP 보안 특징**:
- ✅ ECR 스캔으로 CRITICAL 취약점 차단
- ✅ AWS Secrets Manager 통합
- ✅ External Secrets Operator (ASM → K8s Secret 자동 동기화)
- ⚠️ GitHub Public (코드 노출 위험)

**CGV 보안 특징**:
- ✅ GitLab 자체 호스팅 (외부 노출 최소화)
- ✅ Client VPN (개발자만 접근)
- ✅ SonarQube (코드 품질 사전 검사)
- ✅ Dependency Check (의존성 취약점 사전 차단)
- ✅ PrivateLink (ECR 전송 시 외부 인터넷 미사용)
- ✅ AWS Backup (GitLab EC2 3시간 주기 백업)

---

### 4️⃣ 배포 전략

| 항목 | ERP | CGV |
|------|-----|-----|
| **배포 도구** | Helm (buildspec.yml에서 실행) | ArgoCD (GitOps) |
| **배포 방식** | Push (CodeBuild가 helm upgrade) | Pull (ArgoCD가 Git 감시) |
| **롤백** | helm rollback (CLI) | ArgoCD UI (클릭) |
| **Drift Detection** | 없음 | 있음 (Git ↔ Cluster 비교) |
| **배포 승인** | 없음 (자동) | 있음 (운영계는 수동 승인) |

**ERP 배포 흐름**:
```
Git Push → CodePipeline → CodeBuild → helm upgrade → EKS
```

**CGV 배포 흐름**:
```
Git Push → GitLab Runner → ECR Push
→ ArgoCD 감지 → Sync → EKS
```

**비교**:
- ERP: 빠름 (한 번에 배포), 단순함
- CGV: 안전함 (Drift Detection), 롤백 용이

---

### 5️⃣ 모니터링

| 항목 | ERP | CGV |
|------|-----|-----|
| **로그** | CloudWatch Logs (Fluent Bit) | CloudWatch Logs |
| **트레이싱** | X-Ray (HTTP만) | 없음 |
| **메트릭** | CloudWatch Metrics | Datadog + CloudWatch |
| **알림** | SNS Email | Datadog → Slack |
| **DR 감지** | 없음 | Route53 Health Check → EventBridge |

**ERP 모니터링 특징**:
- ✅ X-Ray 분산 트레이싱 (HTTP 서비스 + Lambda)
- ✅ CloudWatch Alarm (ERROR 로그, Pod 재시작, Lambda 에러)
- ✅ SNS 이메일 알림
- ✅ Fluent Bit DaemonSet (모든 Pod 로그 수집)

**CGV 모니터링 특징**:
- ✅ Datadog (EKS 내부 자원 통합 모니터링)
- ✅ Slack 실시간 알림 (팀 협업)
- ✅ DR 자동 복구 (Route53 → EventBridge → Step Functions)
- ✅ CloudWatch + Datadog 이중 모니터링

---

### 6️⃣ 인프라 규모

| 항목 | ERP | CGV |
|------|-----|-----|
| **환경** | 1개 (Dev) | 4개 (Prod/Dev/QA/DR) |
| **리전** | 1개 (서울) | 2개 (서울/도쿄) |
| **EKS 노드** | 4개 | 운영계: 다수 (KEDA + Karpenter) |
| **데이터베이스** | RDS MySQL | Aurora Global DB |
| **대기열** | 없음 | Redis + Kinesis |
| **오토스케일링** | HPA만 | KEDA + Karpenter + RDS Proxy |
| **DR** | 없음 | 자동 복구 (RTO 5분, RPO 1초) |

**ERP 특징**:
- ✅ 단일 환경 (개발 집중)
- ✅ Lambda 하이브리드 (비용 21% 절감)
- ✅ 간단한 구조 (학습 용이)

**CGV 특징**:
- ✅ 엔터프라이즈급 (4개 환경)
- ✅ Multi-Region (DR 자동 복구)
- ✅ 대규모 트래픽 처리 (10만 동시 접속)
- ✅ 고급 오토스케일링 (KEDA + Karpenter)

---

### 7️⃣ 비용

| 항목 | ERP | CGV |
|------|-----|-----|
| **CI/CD** | CodePipeline + CodeBuild | GitLab EC2 + ArgoCD (무료) |
| **모니터링** | CloudWatch (저렴) | Datadog (유료) + CloudWatch |
| **컴퓨팅** | EKS 3서비스 + Lambda 1개 | EKS 다수 서비스 |
| **데이터베이스** | RDS MySQL (저렴) | Aurora Global DB (비쌈) |
| **총 비용** | ~$100/월 | ~$500/월 (추정) |

**ERP 비용 절감 전략**:
- ✅ Lambda 하이브리드 (Employee Service)
- ✅ RDS MySQL (Aurora 대신)
- ✅ CloudWatch만 사용 (Datadog 없음)

**CGV 비용 특징**:
- ⚠️ Aurora Global DB (비쌈)
- ⚠️ Datadog (유료)
- ⚠️ Multi-Region (2배 비용)
- ✅ 대규모 트래픽 처리 가능

---

## 🎯 ERP에 CGV 기술 적용 가능성

### ⚠️ **중요: AWS Native vs GitOps 선택**

**ERP는 AWS Native를 유지하는 것이 더 유리합니다!**

| 항목 | CodePipeline (현재) | ArgoCD (CGV) |
|------|-------------------|-------------|
| **AWS 통합** | ✅ 완벽 (IAM, CloudWatch, X-Ray) | ⚠️ 별도 설정 필요 |
| **학습 곡선** | ✅ 낮음 (AWS Console) | ⚠️ 높음 (GitOps 개념) |
| **설정 복잡도** | ✅ 간단 (클릭 몇 번) | ⚠️ 복잡 (YAML 작성) |
| **비용** | ✅ 저렴 (빌드 시간만) | ⚠️ 추가 비용 (ArgoCD Pod) |
| **Drift Detection** | ❌ 없음 | ✅ 있음 |
| **롤백** | ✅ helm rollback (CLI) | ✅ ArgoCD UI (클릭) |

**결론**: 
- **개인 프로젝트 (ERP)**: CodePipeline 유지 (AWS Native 장점 극대화)
- **팀 프로젝트 (CGV)**: ArgoCD 도입 (GitOps, Drift Detection)

---

### 1️⃣ 즉시 적용 가능 (우선순위 높음)

#### **SonarQube + Dependency Check 추가**

**현재 (ERP)**:
```
Git Push → CodeBuild → Maven 빌드 → Docker 빌드 → ECR 푸시
```

**개선 (CGV 방식)**:
```
Git Push → CodeBuild
→ SonarQube (코드 품질)
→ Dependency Check (취약점)
→ Maven 빌드
→ Docker 빌드
→ ECR 푸시
```

**구현 방법**:
```yaml
# buildspec.yml에 추가
phases:
  pre_build:
    commands:
      # SonarQube 스캔
      - |
        if [ -n "$CHANGED_SERVICES" ]; then
          for SERVICE in $CHANGED_SERVICES; do
            cd backend/$SERVICE
            mvn sonar:sonar \
              -Dsonar.projectKey=$SERVICE \
              -Dsonar.host.url=http://sonarqube.erp-dev.svc.cluster.local:9000 \
              -Dsonar.login=$SONAR_TOKEN
            cd ../..
          done
        fi
      
      # Dependency Check
      - |
        if [ -n "$CHANGED_SERVICES" ]; then
          for SERVICE in $CHANGED_SERVICES; do
            cd backend/$SERVICE
            mvn org.owasp:dependency-check-maven:check
            cd ../..
          done
        fi
```

---

### 2️⃣ 중기 적용 가능 (우선순위 중간)

#### **DR 구축 (도쿄 리전)**

**현재 (ERP)**:
- 서울 리전만 (장애 시 서비스 중단)

**개선 (CGV 방식)**:
- 도쿄 리전 DR 구축
- Aurora Global DB (RDS → Aurora 전환)
- ECR Cross-Region Replication
- Step Functions 자동 복구

**구현 방법**:
```hcl
# Terraform으로 Aurora Global DB 생성
resource "aws_rds_global_cluster" "erp" {
  global_cluster_identifier = "erp-global"
  engine                    = "aurora-mysql"
  engine_version            = "8.0.mysql_aurora.3.04.0"
}

resource "aws_rds_cluster" "primary" {
  provider                  = aws.seoul
  cluster_identifier        = "erp-primary"
  global_cluster_identifier = aws_rds_global_cluster.erp.id
  engine                    = "aurora-mysql"
  engine_version            = "8.0.mysql_aurora.3.04.0"
}

resource "aws_rds_cluster" "secondary" {
  provider                  = aws.tokyo
  cluster_identifier        = "erp-secondary"
  global_cluster_identifier = aws_rds_global_cluster.erp.id
  engine                    = "aurora-mysql"
  engine_version            = "8.0.mysql_aurora.3.04.0"
  depends_on                = [aws_rds_cluster.primary]
}
```

---

#### **KEDA + Karpenter 오토스케일링**

**현재 (ERP)**:
- HPA만 (CPU 기반)

**개선 (CGV 방식)**:
- KEDA (Kafka 메시지 큐 길이 기반)
- Karpenter (빠른 노드 프로비저닝)

**구현 방법**:
```yaml
# KEDA ScaledObject (Kafka 기반)
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: approval-processing-scaler
  namespace: erp-dev
spec:
  scaleTargetRef:
    name: approval-processing-service
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
  - type: kafka
    metadata:
      bootstrapServers: kafka.erp-dev.svc.cluster.local:9092
      consumerGroup: approval-processing-group
      topic: approval-requests
      lagThreshold: "10"
```

---

### 3️⃣ 장기 적용 가능 (우선순위 낮음)

#### **Datadog 모니터링**

**현재 (ERP)**:
- CloudWatch + X-Ray

**개선 (CGV 방식)**:
- Datadog + CloudWatch (이중 모니터링)
- Slack 실시간 알림

**비용**:
- Datadog: $15/host/월 (4 노드 = $60/월)

---

#### **Velero 백업**

**현재 (ERP)**:
- 백업 없음

**개선 (CGV 방식)**:
- Velero (Kubernetes 리소스 백업)
- S3 스냅샷

**구현 방법**:
```bash
# Velero 설치
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket erp-velero-backup \
  --backup-location-config region=ap-northeast-2 \
  --snapshot-location-config region=ap-northeast-2

# 백업 생성
velero backup create erp-dev-backup --include-namespaces erp-dev
```

---

## 📊 최종 비교 요약

### ERP 프로젝트 강점 (AWS Native)

| 항목 | 설명 |
|------|------|
| **AWS Native 완벽 통합** | CodePipeline, CodeBuild, CloudWatch, X-Ray 자동 연동 |
| **간단한 설정** | AWS Console 클릭 몇 번으로 파이프라인 생성 |
| **낮은 학습 곡선** | GitOps 개념 불필요, AWS 문서만 참고 |
| **Lambda 하이브리드** | Employee Service Lambda 전환 (비용 21% 절감) |
| **X-Ray 트레이싱** | HTTP 서비스 + Lambda 분산 추적 |
| **Git diff 변경 감지** | 변경된 서비스만 빌드 (시간 절약) |
| **External Secrets** | ASM → K8s Secret 자동 동기화 |
| **ECR 스캔 통합** | CRITICAL 취약점 자동 차단 |

### CGV 프로젝트 강점 (GitOps + 엔터프라이즈)

| 항목 | 설명 |
|------|------|
| **GitOps** | ArgoCD Drift Detection, 롤백 용이 |
| **보안 강화** | GitLab 자체 호스팅, SonarQube, Dependency Check |
| **Multi-Region DR** | 자동 복구 (RTO 5분, RPO 1초) |
| **고급 오토스케일링** | KEDA + Karpenter + RDS Proxy |
| **엔터프라이즈급** | 4개 환경 (Prod/Dev/QA/DR) |
| **이중 백업** | AWS Backup + Velero |

### 면접 어필 포인트

**Q: ERP와 CGV 프로젝트의 차이점은?**

**A**: "ERP는 **AWS Native CI/CD**(CodePipeline + CodeBuild)로 빠른 구축과 완벽한 AWS 통합에 집중했습니다. IAM, CloudWatch, X-Ray가 자동으로 연동되고, AWS Console에서 모든 것을 관리할 수 있습니다. 또한 Lambda 하이브리드 구조로 비용을 21% 절감했습니다.

반면 CGV는 **GitOps**(ArgoCD)로 Drift Detection과 롤백 용이성, Multi-Region DR로 고가용성을 달성했습니다. 팀 프로젝트이기 때문에 GitLab 자체 호스팅으로 보안을 강화하고, SonarQube와 Dependency Check로 코드 품질을 사전 검증했습니다.

**ERP의 AWS Native 장점**:
1. **완벽한 통합**: IAM 권한, CloudWatch Logs, X-Ray 트레이싱이 자동 연동
2. **간단한 설정**: AWS Console 클릭 몇 번으로 파이프라인 생성
3. **낮은 학습 곡선**: GitOps 개념 불필요, AWS 문서만 참고
4. **Git diff 변경 감지**: buildspec.yml에서 변경된 서비스만 빌드 (시간 절약)
5. **ECR 스캔 통합**: CRITICAL 취약점 자동 차단

**CGV의 GitOps 장점**:
1. **Drift Detection**: Git과 Cluster 상태 자동 비교
2. **롤백 용이**: ArgoCD UI에서 클릭 한 번
3. **팀 협업**: GitLab 자체 호스팅, SonarQube 코드 리뷰
4. **Multi-Region DR**: 자동 복구 (RTO 5분, RPO 1초)

만약 ERP를 개선한다면, **AWS Native를 유지하면서** SonarQube와 Dependency Check를 CodeBuild에 추가하고, Aurora Global DB로 DR을 구축하며, KEDA로 Kafka 기반 오토스케일링을 추가하고 싶습니다. ArgoCD는 팀 프로젝트에서 Drift Detection이 필요할 때 고려하겠습니다."

---

##  Step 1: 기존 CodePipeline 삭제 (10분)

### 1-1. AWS Console에서 삭제

**방법 1: AWS Console**

1. AWS Console → CodePipeline
2. 4개 파이프라인 선택:
   - `erp-approval-request-pipeline`
   - `erp-approval-processing-pipeline`
   - `erp-employee-pipeline`
   - `erp-notification-pipeline`
3. Actions → Delete
4. 확인

### 1-2. AWS CLI로 삭제

```bash
# 4개 파이프라인 삭제
aws codepipeline delete-pipeline \
  --name erp-approval-request-pipeline \
  --region ap-northeast-2

aws codepipeline delete-pipeline \
  --name erp-approval-processing-pipeline \
  --region ap-northeast-2

aws codepipeline delete-pipeline \
  --name erp-employee-pipeline \
  --region ap-northeast-2

aws codepipeline delete-pipeline \
  --name erp-notification-pipeline \
  --region ap-northeast-2
```

**확인:**
```bash
aws codepipeline list-pipelines --region ap-northeast-2
# 4개 파이프라인이 사라졌는지 확인
```

---

## ✅ Step 2: CodeBuild 프로젝트 생성 (완료)

### 2-1. JSON 파일 생성

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project

cat > codebuild-project.json << 'EOF'
{
  "name": "erp-unified-build",
  "description": "Unified build for all ERP microservices with monitoring",
  "source": {
    "type": "GITHUB",
    "location": "https://github.com/sss654654/erp-microservices.git",
    "buildspec": "buildspec.yml"
  },
  "artifacts": {
    "type": "NO_ARTIFACTS"
  },
  "environment": {
    "type": "LINUX_CONTAINER",
    "image": "aws/codebuild/standard:7.0",
    "computeType": "BUILD_GENERAL1_SMALL",
    "privilegedMode": true
  },
  "serviceRole": "arn:aws:iam::806332783810:role/erp-dev-codebuild-role",
  "logsConfig": {
    "cloudWatchLogs": {
      "status": "ENABLED",
      "groupName": "/aws/codebuild/erp-unified-build",
      "streamName": "build-log"
    }
  }
}
EOF
```

### 2-2. AWS CLI로 생성

```bash
aws codebuild create-project \
  --cli-input-json file://codebuild-project.json \
  --region ap-northeast-2
```

**확인:**
```bash
aws codebuild batch-get-projects \
  --names erp-unified-build \
  --region ap-northeast-2 \
  --query 'projects[0].[name,arn]' \
  --output table
```

**예상 출력:**
```
-----------------------------------------------------------------------------
|                             BatchGetProjects                              |
+---------------------------------------------------------------------------+
|  erp-unified-build                                                        |
|  arn:aws:codebuild:ap-northeast-2:806332783810:project/erp-unified-build  |
+---------------------------------------------------------------------------+
```

---

## ✅ Step 3: CodePipeline 생성 (완료)

### 3-1. S3 버킷 생성 (Artifact 저장용)

```bash
aws s3 mb s3://codepipeline-ap-northeast-2-806332783810 --region ap-northeast-2
```

### 3-2. GitHub Connection 확인

```bash
aws codeconnections list-connections \
  --region ap-northeast-2 \
  --query 'Connections[?ProviderType==`GitHub`].[ConnectionName,ConnectionArn,ConnectionStatus]' \
  --output table
```

**예상 출력:**
```
-----------------------------------------------------------------------------------------------------------------------------------------------
|                                                               ListConnections                                                               |
+-----------------------+-------------------------------------------------------------------------------------------------------+-------------+\n|  github-erp-connection|  arn:aws:codeconnections:ap-northeast-2:806332783810:connection/a0f29740-bbcd-419a-84e9-7412a5dded5e  |  AVAILABLE  |
+-----------------------+-------------------------------------------------------------------------------------------------------+-------------+
```

### 3-3. CodePipeline JSON 파일 생성

```bash
cat > codepipeline.json << 'EOF'
{
  "pipeline": {
    "name": "erp-unified-pipeline",
    "roleArn": "arn:aws:iam::806332783810:role/erp-dev-codepipeline-role",
    "artifactStore": {
      "type": "S3",
      "location": "codepipeline-ap-northeast-2-806332783810"
    },
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "Source",
            "actionTypeId": {
              "category": "Source",
              "owner": "AWS",
              "provider": "CodeStarSourceConnection",
              "version": "1"
            },
            "configuration": {
              "ConnectionArn": "arn:aws:codeconnections:ap-northeast-2:806332783810:connection/a0f29740-bbcd-419a-84e9-7412a5dded5e",
              "FullRepositoryId": "sss654654/erp-microservices",
              "BranchName": "main",
              "OutputArtifactFormat": "CODE_ZIP"
            },
            "outputArtifacts": [
              {
                "name": "SourceArtifact"
              }
            ]
          }
        ]
      },
      {
        "name": "Build",
        "actions": [
          {
            "name": "Build",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "configuration": {
              "ProjectName": "erp-unified-build"
            },
            "inputArtifacts": [
              {
                "name": "SourceArtifact"
              }
            ],
            "outputArtifacts": [
              {
                "name": "BuildArtifact"
              }
            ]
          }
        ]
      }
    ]
  }
}
EOF
```

### 3-4. AWS CLI로 생성

```bash
aws codepipeline create-pipeline \
  --cli-input-json file://codepipeline.json \
  --region ap-northeast-2
```

### 3-5. ⚠️ CodePipeline Role 권한 추가 (필수!)

**문제**: CodePipeline Role에 CodeBuild 실행 권한이 없어서 실패

**해결**:
```bash
cat > /tmp/codepipeline-codebuild-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "arn:aws:codebuild:ap-northeast-2:806332783810:project/erp-unified-build"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name erp-dev-codepipeline-role \
  --policy-name CodeBuildAccess \
  --policy-document file:///tmp/codepipeline-codebuild-policy.json \
  --region ap-northeast-2
```

**확인:**
```bash
aws iam list-role-policies \
  --role-name erp-dev-codepipeline-role \
  --region ap-northeast-2
```

---

## ⚠️ Step 4: buildspec.yml 문법 수정 (진행 중)

### 4-1. 발견된 문제

**문제 1**: YAML 문법 오류
- 멀티라인 블록(`- |`) 내에서 일반 명령(`- echo`)을 혼용하면 안 됨
- `export` 키워드가 CodeBuild에서 작동하지 않음

**해결**: 간소화된 buildspec.yml 사용

### 4-2. 간소화된 buildspec.yml (테스트용)

```yaml
version: 0.2

env:
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
      - echo "Installing dependencies..."
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      - helm version
      - wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
      - chmod +x /usr/local/bin/yq
      - kubectl version --client
  
  pre_build:
    commands:
      - echo "Pre-build phase started on $(date)"
      - echo "Logging in to Amazon ECR..."
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
      - echo "Updating kubeconfig..."
      - aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
      - IMAGE_TAG=${CODEBUILD_RESOLVED_SOURCE_VERSION:0:7}
      - echo "Image tag is $IMAGE_TAG"
  
  build:
    commands:
      - echo "Build phase started on $(date)"
      - echo "Building approval-request-service..."
      - cd backend/approval-request-service
      - mvn clean package -DskipTests
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/approval-request-service
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - cd ../..
  
  post_build:
    commands:
      - echo "Post-build phase started on $(date)"
      - echo "Updating Helm values..."
      - yq eval ".services.approvalRequest.image.tag = \"$IMAGE_TAG\"" -i helm-chart/values-dev.yaml
      - echo "Deploying to EKS with Helm..."
      - helm upgrade erp-microservices ./helm-chart --values ./helm-chart/values-dev.yaml --namespace erp-dev --install --wait --timeout 5m
      - kubectl get pods -n erp-dev
      - echo "Build completed successfully on $(date)"

artifacts:
  files:
    - '**/*'
```

---

## 📊 현재 상태 요약

### ✅ 완료된 것
1. **CodeBuild 프로젝트 생성** - `erp-unified-build`
2. **CodePipeline 생성** - `erp-unified-pipeline`
3. **GitHub Connection 연결** - `github-erp-connection` (AVAILABLE)
4. **S3 Artifact 버킷 생성** - `codepipeline-ap-northeast-2-806332783810`
5. **CodePipeline Role 권한 추가** - CodeBuild 실행 권한

### ⚠️ 진행 중
1. **buildspec.yml 문법 수정** - 간소화 버전으로 테스트 중

### 📝 확인 명령어

```bash
# CodeBuild 프로젝트 확인
aws codebuild batch-get-projects --names erp-unified-build --region ap-northeast-2

# CodePipeline 확인
aws codepipeline list-pipelines --region ap-northeast-2

# 파이프라인 상태 확인
aws codepipeline get-pipeline-state --name erp-unified-pipeline --region ap-northeast-2

# 최근 빌드 로그 확인
aws logs tail /aws/codebuild/erp-unified-build --since 5m --region ap-northeast-2
```

---

##  Step 2: CodeBuild 프로젝트 생성 (20분)

### 2-1. AWS Console에서 생성

**CodeBuild 콘솔 → Create build project**

**프로젝트 설정:**
- Project name: `erp-unified-build`
- Description: `Unified build for all ERP microservices with monitoring`

**Source:**
- Source provider: `GitHub`
- Repository: `Repository in my GitHub account`
- GitHub repository: `sss654654/erp-microservices` (본인 저장소)
- Source version: `refs/heads/main`

**Environment:**
- Environment image: `Managed image`
- Operating system: `Amazon Linux`
- Runtime(s): `Standard`
- Image: `aws/codebuild/standard:7.0`
- Image version: `Always use the latest image`
- Environment type: `Linux`
- Privileged:  **체크 필수** (Docker 빌드 필요)
- Service role: `Existing service role`
- Role ARN: `arn:aws:iam::806332783810:role/erp-dev-codebuild-role`

**Buildspec:**
- Build specifications: `Use a buildspec file`
- Buildspec name: `buildspec.yml` (루트)

**Logs:**
- CloudWatch logs:  체크
- Group name: `/aws/codebuild/erp-unified-build`
- Stream name: `build-log`

**Create build project 클릭**

### 2-2. AWS CLI로 생성

```bash
aws codebuild create-project \
  --name erp-unified-build \
  --description "Unified build for all ERP microservices with monitoring" \
  --source type=GITHUB,location=https://github.com/sss654654/erp-microservices.git,buildspec=buildspec.yml \
  --artifacts type=NO_ARTIFACTS \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true \
  --service-role arn:aws:iam::806332783810:role/erp-dev-codebuild-role \
  --logs-config cloudWatchLogs={status=ENABLED,groupName=/aws/codebuild/erp-unified-build,streamName=build-log} \
  --region ap-northeast-2
```

**확인:**
```bash
aws codebuild batch-get-projects \
  --names erp-unified-build \
  --region ap-northeast-2
```

---

## 🔗 Step 3: CodePipeline 생성 (20분)

### 3-1. AWS Console에서 생성

**CodePipeline 콘솔 → Create pipeline**

#### Stage 1: Pipeline settings

- Pipeline name: `erp-unified-pipeline`
- Service role: `New service role`
- Role name: `AWSCodePipelineServiceRole-ap-northeast-2-erp-unified`
- Allow AWS CodePipeline to create a service role:  체크

**Advanced settings:**
- Artifact store: `Default location`
- Encryption key: `Default AWS Managed Key`

**Next 클릭**

#### Stage 2: Add source stage

- Source provider: `GitHub (Version 2)`
- Connection: `Create new connection` (처음이면)
  - Connection name: `github-erp-connection`
  - GitHub Apps → Install a new app
  - GitHub 로그인 → 저장소 선택 → Connect
- Repository name: `sss654654/erp-microservices`
- Branch name: `main`
- Change detection options: `Start the pipeline on source code change`  체크
- Output artifact format: `CodePipeline default`

**Next 클릭**

#### Stage 3: Add build stage

- Build provider: `AWS CodeBuild`
- Region: `Asia Pacific (Seoul)`
- Project name: `erp-unified-build` (방금 생성한 프로젝트)
- Build type: `Single build`

**Next 클릭**

#### Stage 4: Add deploy stage

- **Skip deploy stage** 클릭
  - 이유: buildspec.yml에서 helm upgrade로 배포

**Next 클릭**

#### Stage 5: Review

- 설정 확인
- **Create pipeline 클릭**

### 3-2. AWS CLI로 생성

```bash
# pipeline.json 파일 생성
cat > pipeline.json << 'EOF'
{
  "pipeline": {
    "name": "erp-unified-pipeline",
    "roleArn": "arn:aws:iam::806332783810:role/service-role/AWSCodePipelineServiceRole-ap-northeast-2-erp-unified",
    "artifactStore": {
      "type": "S3",
      "location": "codepipeline-ap-northeast-2-806332783810"
    },
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "Source",
            "actionTypeId": {
              "category": "Source",
              "owner": "AWS",
              "provider": "CodeStarSourceConnection",
              "version": "1"
            },
            "configuration": {
              "ConnectionArn": "arn:aws:codeconnections:ap-northeast-2:806332783810:connection/xxxxx",
              "FullRepositoryId": "sss654654/erp-microservices",
              "BranchName": "main",
              "OutputArtifactFormat": "CODE_ZIP"
            },
            "outputArtifacts": [
              {
                "name": "SourceArtifact"
              }
            ]
          }
        ]
      },
      {
        "name": "Build",
        "actions": [
          {
            "name": "Build",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "configuration": {
              "ProjectName": "erp-unified-build"
            },
            "inputArtifacts": [
              {
                "name": "SourceArtifact"
              }
            ],
            "outputArtifacts": [
              {
                "name": "BuildArtifact"
              }
            ]
          }
        ]
      }
    ]
  }
}
EOF

# 파이프라인 생성
aws codepipeline create-pipeline \
  --cli-input-json file://pipeline.json \
  --region ap-northeast-2
```

---

##  Step 4: 검증 (10분)

### 4-1. 파이프라인 확인

**AWS Console:**
1. CodePipeline → `erp-unified-pipeline`
2. 상태 확인:
   - Source: Succeeded
   - Build: In Progress / Succeeded

**AWS CLI:**
```bash
aws codepipeline get-pipeline-state \
  --name erp-unified-pipeline \
  --region ap-northeast-2
```

### 4-2. CodeBuild 로그 확인

**AWS Console:**
1. CodeBuild → Build history
2. `erp-unified-build` 클릭
3. Build logs 확인:
   - Parameter Store 읽기 성공
   - ECR 로그인 성공
   - Git diff 변경 감지
   - Maven 빌드 성공
   - Docker 빌드/푸시 성공
   - ECR 스캔 성공
   - Lambda 함수 업데이트 (employee-service 변경 시)
   - Helm values 업데이트
   - Helm 배포 성공

**AWS CLI:**
```bash
# 최근 빌드 ID 확인
BUILD_ID=$(aws codebuild list-builds-for-project \
  --project-name erp-unified-build \
  --region ap-northeast-2 \
  --query 'ids[0]' \
  --output text)

# 빌드 로그 확인
aws codebuild batch-get-builds \
  --ids $BUILD_ID \
  --region ap-northeast-2 \
  --query 'builds[0].logs.deepLink' \
  --output text
```

### 4-3. EKS 배포 확인

```bash
# Pod 상태 확인
kubectl get pods -n erp-dev

# Service 확인
kubectl get svc -n erp-dev

# Helm 히스토리 확인
helm history erp-microservices -n erp-dev

# 이미지 태그 확인 (Git 커밋 해시 7자리)
kubectl get deployment -n erp-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

### 4-4. Lambda 함수 확인 (employee-service 변경 시)

```bash
# Lambda 함수 이미지 확인
aws lambda get-function \
  --function-name erp-dev-employee-service \
  --region ap-northeast-2 \
  --query 'Code.ImageUri' \
  --output text

# 예상 출력: 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service-lambda:a1b2c3d
```

### 4-5. 모니터링 확인

```bash
# CloudWatch Logs 확인
aws logs tail /aws/eks/erp-dev/application --since 5m --region ap-northeast-2

# X-Ray 트레이스 확인
aws xray get-trace-summaries \
  --start-time $(date -u -d '10 minutes ago' +%s) \
  --end-time $(date -u +%s) \
  --region ap-northeast-2

# CloudWatch Alarm 상태 확인
aws cloudwatch describe-alarms \
  --alarm-names erp-dev-high-error-rate erp-dev-pod-restarts erp-dev-lambda-error-rate \
  --region ap-northeast-2 \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table
```

---

##  Step 5: Git Push 테스트 (10분)

### 5-1. 코드 변경 (EKS 서비스)

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project

# Approval Request Service 코드 변경
echo "// Test change for CI/CD" >> backend/approval-request-service/src/main/java/com/erp/approval/ApprovalController.java

# Git 커밋
git add .
git commit -m "Test: Trigger unified pipeline - approval-request-service"
git push origin main
```

**예상 동작:**
1. GitHub Webhook → CodePipeline 트리거
2. Source Stage: GitHub에서 코드 가져오기
3. Build Stage: CodeBuild 실행
   - Git diff로 approval-request-service 변경 감지
   - approval-request-service만 빌드
   - ECR 푸시 + 스캔
   - Helm values 업데이트 (approvalRequest.image.tag)
   - helm upgrade 실행
4. EKS에 approval-request-service만 재배포

### 5-2. 코드 변경 (Lambda)

```bash
# Employee Service 코드 변경
echo "// Test change for Lambda" >> backend/employee-service/src/main/java/com/erp/employee/EmployeeController.java

# Git 커밋
git add .
git commit -m "Test: Trigger unified pipeline - employee-service Lambda"
git push origin main
```

**예상 동작:**
1. GitHub Webhook → CodePipeline 트리거
2. Build Stage: CodeBuild 실행
   - Git diff로 employee-service 변경 감지
   - employee-service Lambda 이미지 빌드
   - ECR 푸시 + 스캔
   - Lambda 함수 업데이트 (aws lambda update-function-code)
3. Lambda 함수 재시작 (새 이미지 사용)

### 5-3. Helm Chart 변경

```bash
# Helm Chart values 변경 (replicas 증가)
sed -i 's/replicaCount: 2/replicaCount: 3/' helm-chart/values-dev.yaml

# Git 커밋
git add .
git commit -m "Test: Increase replicas to 3"
git push origin main
```

**예상 동작:**
1. GitHub Webhook → CodePipeline 트리거
2. Build Stage: CodeBuild 실행
   - Git diff로 helm-chart/ 변경 감지
   - HELM_CHANGED=true
   - 모든 EKS 서비스 재배포 (이미지 빌드는 스킵)
   - helm upgrade 실행
3. EKS에 모든 서비스 Pod 3개로 증가

### 5-4. 변경 감지 로그 확인

**CodeBuild 로그에서 확인:**
```
========================================
Detecting changed services...
Changed files:
backend/approval-request-service/src/main/java/com/erp/approval/ApprovalController.java
✓ approval-request-service changed
Services to build: approval-request-service
Lambda changed: false
Helm changed: false
========================================
```

---

##  트러블슈팅

### 문제 1: GitHub 연결 실패

**증상:**
```
Could not connect to GitHub repository
```

**해결:**
1. CodePipeline → Settings → Connections
2. `github-erp-connection` 상태 확인
3. Status가 `Pending`이면:
   - Update pending connection 클릭
   - GitHub 로그인 → 권한 승인

### 문제 2: CodeBuild 권한 오류

**증상:**
```
AccessDeniedException: User is not authorized to perform: eks:DescribeCluster
```

**해결:**
```bash
# CodeBuild Role에 EKS 권한 추가 (이미 02단계에서 완료)
aws iam list-role-policies --role-name erp-dev-codebuild-role --region ap-northeast-2
# 8개 정책 확인:
# - codebuild-secrets-policy
# - codebuild-ssm-policy
# - codebuild-ecr-scan-policy
# - codebuild-ecr-policy
# - codebuild-eks-policy
# - codebuild-logs-policy
# - codebuild-s3-policy
# - codebuild-codeconnections-policy
```

### 문제 3: Helm 배포 실패

**증상:**
```
Error: UPGRADE FAILED: unable to build kubernetes objects
```

**해결:**
```bash
# Helm Chart 문법 확인
cd helm-chart
helm lint . -f values-dev.yaml

# Dry-run 테스트
helm template . -f values-dev.yaml > test-output.yaml
kubectl apply -f test-output.yaml --dry-run=client
```

### 문제 4: ECR 스캔 타임아웃

**증상:**
```
WARNING: Scan timeout for approval-request-service, proceeding with deployment
```

**원인:**
- ECR 스캔이 10분 이상 소요
- buildspec.yml의 MAX_RETRIES=30 (5분) 초과

**해결:**
```yaml
# buildspec.yml 수정
for i in {1..60}; do  # 30 → 60 (10분으로 증가)
  SCAN_STATUS=$(aws ecr describe-image-scan-findings ...)
  ...
done
```

### 문제 5: Lambda 함수 업데이트 실패

**증상:**
```
An error occurred (ResourceConflictException) when calling the UpdateFunctionCode operation: 
The operation cannot be performed at this time. An update is in progress for resource: xxx
```

**원인:**
- Lambda 함수가 이전 업데이트 중

**해결:**
```bash
# Lambda 함수 상태 확인
aws lambda get-function \
  --function-name erp-dev-employee-service \
  --region ap-northeast-2 \
  --query 'Configuration.LastUpdateStatus' \
  --output text

# Successful이 될 때까지 대기 (buildspec.yml에 자동 재시도 로직 추가)
```

---

##  완료 체크리스트

- [ ] 기존 4개 CodePipeline 삭제
- [ ] CodeBuild 프로젝트 생성 (`erp-unified-build`)
- [ ] CodePipeline 생성 (`erp-unified-pipeline`)
- [ ] GitHub 연결 설정 완료
- [ ] 파이프라인 첫 실행 성공
- [ ] CodeBuild 로그 확인 (Parameter Store, Git diff, ECR 스캔, Helm 배포)
- [ ] EKS 배포 확인 (Pod, Service, Helm)
- [ ] Lambda 함수 확인 (employee-service 변경 시)
- [ ] 모니터링 확인 (CloudWatch Logs, X-Ray, CloudWatch Alarm)
- [ ] Git Push 테스트 성공 (EKS 서비스, Lambda, Helm Chart)
- [ ] 변경 감지 로직 동작 확인

---

##  다음 단계

**CodePipeline 생성 완료!**

**다음 파일을 읽으세요:**
→ **08_VERIFICATION.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 08_VERIFICATION.md
```

---

##  개선 효과

### Before (4개 파이프라인)

```
파이프라인 관리: 4개
배포 시간: 각 5분 × 4 = 20분
변경 감지: 폴더별 감시 (부정확)
Manifests 반영: 안 됨
롤백: 불가능
모니터링: 없음
```

### After (1개 파이프라인)

```
파이프라인 관리: 1개
배포 시간: 변경된 서비스만 (평균 5분)
변경 감지: Git diff (정확)
Manifests 반영: 자동 (Helm)
롤백: helm rollback (즉시)
모니터링: CloudWatch Logs + X-Ray + CloudWatch Alarm
```

---

**"단일 파이프라인으로 모든 서비스를 관리합니다. Git Push 한 번으로 빌드 → 스캔 → 배포 → 모니터링까지 완전 자동화!"**
