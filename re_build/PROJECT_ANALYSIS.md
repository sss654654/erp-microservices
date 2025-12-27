# ERP 프로젝트 분석 및 재구축 가이드

작성일: 2024-12-27

---

## 목차

1. [현재 상황 분석](#현재-상황-분석)
2. [발견된 문제점](#발견된-문제점)
3. [Terraform 구조 분석](#terraform-구조-분석)
4. [재구축 해결 방안](#재구축-해결-방안)

---

## 현재 상황 분석

### 프로젝트 배경

**CGV 프로젝트 경험:**
- GitLab CI + ArgoCD + Helm Chart 사용
- 전체 CI/CD 구조는 팀에서 구축된 것 활용
- 한계: 파이프라인 전체 흐름 이해했지만 직접 설계 경험 부족

**ERP 프로젝트 목표:**
- AWS 네이티브 도구 (CodePipeline, CodeBuild) 실전 적용
- CI/CD 파이프라인을 처음부터 끝까지 직접 설계

**결과: 실패한 설계**
- 서비스별 독립 파이프라인 (4개 CodePipeline)
- kubectl set image만 실행 (Manifests 변경 반영 안 됨)
- Git이 진실이 아님
- 환경 분리 불가능

---

## 발견된 문제점

### 1. CI/CD 구조 문제

**서비스별 독립 파이프라인**
- 4개 마이크로서비스 = 4개 CodePipeline = 4개 buildspec.yml
- Manifests 변경이 배포 안 됨
- 서비스 간 의존성 무시
- 롤백 불가능

**buildspec.yml 위치**
- backend/서비스명/buildspec.yml (4개 중복)
- 변경 시 4개 파일 모두 수정 필요

**kubectl set image만 실행**
```yaml
post_build:
  commands:
    - kubectl set image deployment/서비스명 ...
```
- 이미지만 변경
- Deployment의 나머지 설정은 그대로 유지
- Manifests 변경 반영 안 됨

### 2. Manifests 구조 문제

**Plain YAML (하드코딩)**
- 환경별 설정 분리 불가능
- 4개 Deployment 파일 중복 (400줄 중 300줄 중복)
- 버전 관리 어려움

**Secret 평문 저장**
```yaml
# manifests/base/secret.yaml
stringData:
  MYSQL_PASSWORD: "123456789"  # Git에 평문 커밋
```

**LoadBalancer 중복**
```yaml
# manifests/notification/notification-service.yaml
spec:
  type: LoadBalancer  # 추가 NLB 생성
```
- Terraform NLB + Kubernetes LoadBalancer = NLB 2개
- 비용 낭비 ($16/월)

### 3. 인프라 구조 문제

**NLB 중복 생성**
- Terraform: erp-dev-nlb (4개 Target Group)
- Kubernetes: LoadBalancer Service (notification)
- 결과: NLB 2개 사용 중

**Lambda 미사용**
- Employee Service는 간단한 CRUD (Lambda 적합)
- 비용 최적화 기회 놓침 (21% 절감 가능)

**Kafka Deployment**
- StatefulSet 아닌 Deployment 사용
- 데이터 영속성 없음
- Pod 재시작 시 메시지 소실

---

## Terraform 구조 분석

### 전체 구조 (98개 .tf 파일)

**1. VPC (세분화 - 3단계)**
```
erp-dev-VPC/
├── vpc/          # VPC + IGW
├── subnet/       # Public/Private/Data Subnet + NAT
└── route-table/  # Route Table + Associations
```

**2. SecurityGroups (세분화 - 4개 독립)**
```
erp-dev-SecurityGroups/
├── alb-sg/
├── eks-sg/
├── rds-sg/
└── elasticache-sg/
```

**3. IAM (통합 - 1번 apply)**
```
erp-dev-IAM/
├── eks-cluster-role/
├── eks-node-role/
├── codebuild-role/    # 권한 추가 필요
└── codepipeline-role/
```

**4. Secrets (통합 - 1번 apply)**
```
erp-dev-Secrets/
├── mysql-secret/              # Secret 이름: erp/dev/mysql
└── eks-node-secrets-policy/   # EKS Node에 읽기 권한
```

**5. Databases (세분화 - 2개 독립)**
```
erp-dev-Databases/
├── rds/          # MySQL 8.0, db.t3.micro
└── elasticache/  # Redis 7.0, cache.t3.micro
```

**6. EKS (통합 - 1번 apply)**
```
erp-dev-EKS/
├── eks-cluster/           # Kubernetes 1.31
├── eks-node-group/        # t3.small × 3
└── eks-cluster-sg-rules/  # VPC ingress (NLB용)
```

**7. LoadBalancerController (단일)**
- Helm Release v1.7.0
- IAM Role for ServiceAccount

**8. APIGateway (통합 - 1번 apply)**
```
erp-dev-APIGateway/
├── nlb/          # NLB + 4 Target Groups
└── api-gateway/  # HTTP API + 7 Routes
```

**9. Frontend (통합)**
```
erp-dev-Frontend/
├── s3/          # Static Website Hosting
└── cloudfront/  # CDN
```

**10. Cognito (통합)**
- User Pool + Lambda auto-confirm

### 주요 발견 사항

**Secret 이름**
- 실제: erp/dev/mysql
- MongoDB Secret 없음 (Atlas 사용)

**CodeBuild Role 권한 부족**
- Secrets Manager 읽기 권한 없음
- Parameter Store 읽기 권한 없음
- ECR 이미지 스캔 권한 없음

**EKS Node 3개 이유**
- Kafka 메모리 요구사항
- 서비스 Pod Anti-Affinity 분산

---

## 재구축 해결 방안

### 1. Helm Chart 전환

**Before (Plain YAML):**
- 4개 Deployment 파일 중복
- 환경 분리 불가

**After (Helm Chart):**
- 1개 템플릿 → 4개 Deployment 생성
- values-dev.yaml / values-prod.yaml 분리

### 2. 단일 buildspec.yml

**Before:**
```yaml
# backend/서비스명/buildspec.yml (4개)
post_build:
  - kubectl set image deployment/서비스명 ...
```

**After:**
```yaml
# 루트/buildspec.yml (1개)
post_build:
  - helm upgrade --install erp-microservices helm-chart/ \
      -f helm-chart/values-dev.yaml
```

### 3. Secrets Manager 통합

**Before:**
```yaml
# manifests/base/secret.yaml
stringData:
  MYSQL_PASSWORD: "123456789"
```

**After:**
```yaml
# External Secrets Operator
# Secrets Manager에서 자동 동기화
# Git에 Secret 없음
```

### 4. NLB 중복 제거

**Before:**
- Terraform NLB + Kubernetes LoadBalancer

**After:**
- 모든 Service를 ClusterIP
- TargetGroupBinding으로 Terraform NLB 연결

### 5. CodePipeline 강점 극대화

**CGV와 차별화:**
- AWS Secrets Manager 통합
- Parameter Store 활용
- ECR 이미지 스캔 자동화
- CloudWatch Logs 중앙 집중
- 변경 감지 로직 (Git diff)

---

## 재구축 단계

**Phase 0:** 준비 및 백업
**Phase 1:** Terraform 배포 (2시간)
**Phase 2:** Helm Chart 생성 (2시간)
**Phase 2.5:** Lambda 전환 (선택, 2시간)
**Phase 3:** Secrets Manager 설정 (30분)
**Phase 4:** buildspec.yml 작성 (1시간)
**Phase 5:** CodePipeline 생성 (1시간)
**Phase 6:** 검증 및 테스트 (1시간)

총 소요 시간: 9.5시간 (Lambda 포함)

---

## 개선 효과

### Before (문제)
- 4개 CodePipeline (관리 복잡)
- kubectl set image (Manifests 반영 안 됨)
- Plain YAML (환경 분리 불가)
- Secret 평문 (보안 취약)
- NLB 중복 (비용 낭비)
- Git이 진실 아님

### After (해결)
- 1개 CodePipeline (단일 관리)
- helm upgrade (Manifests 자동 반영)
- Helm Chart (환경 분리 가능)
- Secrets Manager (보안 강화)
- NLB 1개 (비용 절감)
- Git이 진실 (Source of Truth)

---

## 참고 사항

**MongoDB URI:**
- Atlas 외부 서비스 사용
- Secrets Manager 불필요
- ConfigMap에 URI 하드코딩 (개발 환경)

**Kafka 구조:**
- Deployment 유지 (StatefulSet 아님)
- 개발 환경이므로 메시지 소실 허용
- 비용 절감 (MSK $310/월 vs 현재 $0)

**Lambda 전환 (선택):**
- Employee Service만 가능
- 비용 21% 절감 ($82.30 → $64.73)
- Cold Start 300~500ms (첫 요청만)
