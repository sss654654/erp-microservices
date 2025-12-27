# 🚀 ERP 프로젝트 재구축 마스터 가이드

**작성일**: 2024-12-27  
**목적**: 처음부터 끝까지 완벽한 재구축 (CodePipeline 강점 극대화)

---

## 📋 이 가이드를 읽는 방법

### 파일 구조
```
re_build/
├── 00_START_HERE.md           # ← 지금 읽는 파일 (전체 개요)
├── 01_TERRAFORM.md             # Terraform 배포 (2시간)
├── 02_HELM_CHART.md            # Helm Chart 생성 (2시간)
├── 02.5_LAMBDA.md              # Lambda 전환 (2시간) ← NEW
├── 03_SECRETS_SETUP.md         # Secrets Manager 설정 (30분)
├── 04_BUILDSPEC.md             # buildspec.yml 작성 (1시간)
├── 05_CODEPIPELINE.md          # CodePipeline 생성 (1시간)
└── 06_VERIFICATION.md          # 검증 및 테스트 (1시간)
```

### 읽는 순서
1. **00_START_HERE.md** (이 파일) - 전체 흐름 이해
2. **01_TERRAFORM.md** - Terraform 배포 시작
3. **02_HELM_CHART.md** - Helm Chart 생성
4. **02.5_LAMBDA.md** - Employee Service Lambda 전환 ← NEW
5. **03_SECRETS_SETUP.md** - Secrets Manager 설정
6. **04_BUILDSPEC.md** - buildspec.yml 작성
7. **05_CODEPIPELINE.md** - CodePipeline 생성
8. **06_VERIFICATION.md** - 검증 및 테스트

---

## 🎯 재구축 목표

### 해결할 문제점

**현재 문제:**
1. ❌ 서비스별 CodePipeline (4개)
2. ❌ kubectl set image만 실행 (Manifests 변경 반영 안 됨)
3. ❌ Plain YAML (환경 분리 불가)
4. ❌ Secret 평문 하드코딩
5. ❌ NLB 중복 생성
6. ❌ Git이 진실이 아님

**재구축 후:**
1. ✅ 단일 CodePipeline
2. ✅ helm upgrade (전체 리소스 배포)
3. ✅ Helm Chart (환경 분리 가능)
4. ✅ AWS Secrets Manager 통합
5. ✅ NLB 1개로 통일
6. ✅ Git이 진실

### CodePipeline 강점 극대화

**CGV와 차별화:**
1. ✅ AWS Secrets Manager 통합
2. ✅ Parameter Store 활용
3. ✅ CodeBuild 환경 변수 암호화
4. ✅ ECR 이미지 스캔 자동화
5. ✅ CloudWatch Logs 중앙 집중
6. ✅ X-Ray 트레이싱 통합
7. ✅ 단일 파이프라인 + Helm Chart

---

## 📊 전체 흐름도

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Terraform 배포 (2시간)                              │
│ - VPC, Subnet, Security Groups                              │
│ - IAM Roles                                                  │
│ - RDS, ElastiCache                                           │
│ - EKS Cluster, Node Group                                    │
│ - NLB, API Gateway                                           │
│ - Frontend (S3, CloudFront)                                  │
│ - Cognito                                                    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Helm Chart 생성 (2시간)                             │
│ - Chart.yaml                                                 │
│ - values-dev.yaml (환경별 설정)                              │
│ - templates/ (Deployment, Service, HPA 등)                   │
│ - External Secrets 연동                                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: Secrets Manager 설정 (30분)                         │
│ - RDS 비밀번호 저장                                          │
│ - MongoDB URI 저장                                           │
│ - External Secrets Operator 설치                            │
│ - SecretStore 생성                                           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 4: buildspec.yml 작성 (1시간)                          │
│ - Secrets Manager 통합                                       │
│ - Parameter Store 활용                                       │
│ - ECR 이미지 스캔 자동화                                     │
│ - CloudWatch Logs 전송                                       │
│ - X-Ray 트레이싱                                             │
│ - Helm upgrade 명령                                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 5: CodePipeline 생성 (1시간)                           │
│ - 단일 파이프라인 생성                                       │
│ - CodeBuild 프로젝트 생성                                    │
│ - IAM 권한 설정                                              │
│ - GitHub 연동                                                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 6: 검증 및 테스트 (1시간)                              │
│ - Helm 배포 확인                                             │
│ - Pod 상태 확인                                              │
│ - API Gateway 테스트                                         │
│ - Git Push 테스트                                            │
└─────────────────────────────────────────────────────────────┘
```

---

## ⏱️ 예상 소요 시간

| Phase | 작업 | 소요 시간 |
|-------|------|----------|
| Phase 1 | Terraform 배포 | 2시간 |
| Phase 2 | Helm Chart 생성 | 2시간 |
| Phase 2.5 | Lambda 전환 (Employee Service) | 2시간 |
| Phase 3 | Secrets Manager 설정 | 30분 |
| Phase 4 | buildspec.yml 작성 | 1시간 |
| Phase 5 | CodePipeline 생성 | 1시간 |
| Phase 6 | 검증 및 테스트 | 1시간 |
| **합계** | | **9.5시간** |

**실제 소요 시간: 2일 (휴식 포함)**

---

## 🔑 핵심 개념

### 1. Terraform 세분화 vs 통합

**세분화 (독립 apply):**
- VPC (vpc, subnet, route-table)
- Security Groups (eks-sg, rds-sg, elasticache-sg, alb-sg)
- Databases (rds, elasticache)

**통합 (main.tf로 한 번에 apply):**
- IAM (강한 의존성)
- EKS (cluster + node-group)
- API Gateway (nlb + vpc-link + api-gateway)
- Frontend (s3 + cloudfront)

### 2. Helm Chart 구조

```
helm-chart/
├── Chart.yaml              # 메타데이터
├── values-dev.yaml         # 개발계 설정
├── values-prod.yaml        # 운영계 설정 (미래)
└── templates/
    ├── deployment.yaml     # 4개 서비스 통합
    ├── service.yaml        # ClusterIP (모두)
    ├── hpa.yaml            # Auto Scaling
    ├── configmap.yaml      # 환경 변수
    ├── externalsecret.yaml # Secrets Manager 연동
    ├── targetgroupbinding.yaml  # NLB 연결
    └── kafka.yaml          # Kafka + Zookeeper
```

### 3. buildspec.yml 구조

```yaml
env:
  secrets-manager:          # Secret 로드
    DB_PASSWORD: prod/rds/password
  parameter-store:          # 설정 로드
    ECR_REPO: /erp/dev/ecr/repository

phases:
  install:                  # 도구 설치
    - Helm, yq, CloudWatch Agent, X-Ray
  
  pre_build:                # 준비
    - ECR 로그인
    - 변경된 서비스 감지
  
  build:                    # 빌드
    - Maven package
    - Docker build
  
  post_build:               # 배포
    - ECR push + 이미지 스캔
    - Helm values 업데이트
    - helm upgrade
    - CloudWatch Logs 전송
    - X-Ray 트레이싱
```

---

## 🚨 주의사항

### 시작 전 확인

```bash
# 1. AWS CLI 설정 확인
aws sts get-caller-identity

# 2. Terraform 설치 확인
terraform version

# 3. Helm 설치 확인
helm version

# 4. kubectl 설치 확인
kubectl version --client

# 5. Git 상태 확인
git status
```

### 백업

```bash
# 현재 상태 백업 (이미 배포된 경우)
kubectl get all -n erp-dev -o yaml > backup-$(date +%Y%m%d).yaml

# Git 태그 생성
git tag backup-before-rebuild
git push origin backup-before-rebuild
```

---

## 📝 체크리스트

### Phase 1: Terraform
- [ ] VPC 배포 완료
- [ ] Security Groups 배포 완료
- [ ] IAM Roles 배포 완료
- [ ] RDS, ElastiCache 배포 완료
- [ ] EKS Cluster 배포 완료
- [ ] NLB, API Gateway 배포 완료
- [ ] Frontend 배포 완료

### Phase 2: Helm Chart
- [ ] Chart.yaml 작성
- [ ] values-dev.yaml 작성 (employee 제외)
- [ ] templates/ 8개 파일 작성
- [ ] helm lint 통과
- [ ] helm template 출력 확인

### Phase 2.5: Lambda 전환
- [ ] Terraform Lambda 모듈 생성
- [ ] Dockerfile.lambda 생성
- [ ] pom.xml Lambda 의존성 추가
- [ ] Terraform apply 성공
- [ ] Lambda 이미지 빌드 및 푸시
- [ ] API Gateway 테스트 성공

### Phase 3: Secrets Manager
- [ ] RDS Secret 생성
- [ ] MongoDB Secret 생성
- [ ] External Secrets Operator 설치
- [ ] SecretStore 생성

### Phase 4: buildspec.yml
- [ ] Secrets Manager 통합
- [ ] Parameter Store 통합
- [ ] ECR 이미지 스캔 추가
- [ ] CloudWatch Logs 전송 추가
- [ ] X-Ray 트레이싱 추가
- [ ] Helm upgrade 명령 추가

### Phase 5: CodePipeline
- [ ] 단일 파이프라인 생성
- [ ] CodeBuild 프로젝트 생성
- [ ] IAM 권한 설정
- [ ] GitHub 연동

### Phase 6: 검증
- [ ] Helm 배포 성공
- [ ] Pod 모두 Running
- [ ] Service 모두 ClusterIP
- [ ] TargetGroupBinding 연결 확인
- [ ] API Gateway 테스트 성공
- [ ] Git Push 테스트 성공

---

## 🎬 시작하기

**다음 파일을 읽으세요:**
→ **01_TERRAFORM.md**

**명령어:**
```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 01_TERRAFORM.md
```

---

**"천천히, 단계별로, 확인하면서 진행하세요. 성공을 기원합니다!"**
