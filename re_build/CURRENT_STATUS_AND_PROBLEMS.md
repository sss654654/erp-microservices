# ERP 프로젝트 현재 상황 및 문제점 분석

**작성일**: 2024-12-27  
**목적**: 프로젝트 재구축 전 현재 상태 완전 분석

---

## 목차

1. [현재 상황 요약](#1-현재-상황-요약)
2. [CI/CD 구조 문제](#2-cicd-구조-문제)
3. [Manifests 구조 문제](#3-manifests-구조-문제)
4. [인프라 구조 문제](#4-인프라-구조-문제)
5. [코드 레벨 문제](#5-코드-레벨-문제)
6. [재구축 계획](#6-재구축-계획)

---

## 1. 현재 상황 요약

### 프로젝트 배경

**CGV 프로젝트 경험:**
- GitLab CI + ArgoCD + Helm Chart 구조 사용
- values-dev.yaml에 RBAC, Kinesis, 동적 스케일링 설정 추가 (일부 기여)
- 전체 CI/CD 구조는 팀에서 구축된 것을 활용
- **한계**: 파이프라인 전체 흐름을 이해했지만, 직접 설계 경험 부족

**ERP 프로젝트 목표:**
- DVA 자격증 취득 후 AWS 네이티브 도구 (CodePipeline, CodeBuild) 실전 적용
- CI/CD 파이프라인을 **처음부터 끝까지 직접 설계**
- CGV에서 못 다뤄본 부분을 경험하자

**결과: 실패한 설계**
- 서비스별 독립 파이프라인 (4개 CodePipeline)
- `kubectl set image`만 실행 (Manifests 변경 반영 안 됨)
- Git이 진실이 아님 (Drift Detection 없음)
- 환경 분리 불가능 (개발계만 존재)

### 현재 구조

```
GitHub (단일 저장소)
├── backend/
│   ├── approval-request-service/
│   │   ├── src/
│   │   ├── pom.xml
│   │   └── buildspec.yml  # ⚠️ 서비스별 파이프라인
│   ├── approval-processing-service/
│   │   └── buildspec.yml  # ⚠️ 서비스별 파이프라인
│   ├── employee-service/
│   │   └── buildspec.yml  # ⚠️ 서비스별 파이프라인
│   └── notification-service/
│       └── buildspec.yml  # ⚠️ 서비스별 파이프라인
│
├── manifests/              # Plain YAML (하드코딩)
│   ├── base/
│   ├── approval-request/
│   ├── approval-processing/
│   ├── employee/
│   └── notification/
│
└── infrastructure/terraform/dev/  # Terraform IaC
```

**4개 CodePipeline + 4개 CodeBuild**
- approval-request-pipeline → approval-request-service/buildspec.yml
- approval-processing-pipeline → approval-processing-service/buildspec.yml
- employee-pipeline → employee-service/buildspec.yml
- notification-pipeline → notification-service/buildspec.yml

---

## 2. CI/CD 구조 문제

### 문제 1: 서비스별 독립 파이프라인

**현재 구조:**
```
4개 마이크로서비스 = 4개 CodePipeline = 4개 buildspec.yml
```

**문제점:**

#### 1) Manifests 변경이 배포 안 됨

**시나리오:**
```yaml
# manifests/approval-request/approval-request-deployment.yaml 수정
spec:
  replicas: 2 → 5  # 트래픽 증가로 Pod 증가 필요
  resources:
    limits:
      memory: 512Mi → 1Gi  # 메모리 부족으로 증가 필요
```

**Git Push 후:**
```
GitHub Webhook → CodePipeline 트리거
  ↓
CodeBuild 실행
  ↓
buildspec.yml:
  kubectl set image deployment/approval-request-service \
    approval-request-service=$REPOSITORY_URI:a1b2c3d
  # ⚠️ 이미지만 변경, replicas와 resources는 무시됨
  ↓
결과: Manifests 변경사항이 클러스터에 반영 안 됨
```

**실제 상황:**
- Git: replicas=5, memory=1Gi
- 클러스터: replicas=2, memory=512Mi (변경 전 상태 유지)
- **Git이 진실이 아님**

#### 2) 서비스 간 의존성 무시

**시나리오:**
```
approval-request-service 코드 변경
  ↓
approval-request-pipeline만 트리거
  ↓
approval-request-service만 새 버전 배포
  ↓
approval-processing-service는 구버전 유지
  ↓
API 호환성 깨짐 (Kafka 메시지 스키마 변경 시)
```

**문제:**
- 4개 서비스가 독립적으로 배포됨
- 서비스 간 API 버전 불일치 가능
- 통합 테스트 불가능

#### 3) 전체 환경 일관성 없음

**시나리오:**
```
base/configmap.yaml 수정 (REDIS_HOST 변경)
  ↓
Git Push
  ↓
어떤 파이프라인도 트리거 안 됨 (buildspec.yml이 backend/ 폴더만 감시)
  ↓
ConfigMap 변경사항이 클러스터에 반영 안 됨
  ↓
수동으로 kubectl apply -f manifests/base/configmap.yaml 실행 필요
```

#### 4) 롤백 불가능

**시나리오:**
```
approval-request-service 배포 후 버그 발견
  ↓
롤백 시도:
  1. Git revert? → buildspec.yml이 이미지만 변경하므로 소용없음
  2. kubectl rollout undo? → 이전 이미지로 돌아가지만 Git과 불일치
  3. 이전 커밋으로 재배포? → 4분 소요, 긴급 상황에 부적합
```

#### 5) 환경 분리 불가능

**현재:**
```
GitHub main 브랜치 Push
  ↓
CodePipeline 트리거
  ↓
erp-dev 네임스페이스에 즉시 배포
```

**운영계 추가 시:**
```
운영계 파이프라인을 어떻게 만들어야 하나?
- main 브랜치 Push 시 개발계와 운영계 동시 배포? (위험)
- 별도 브랜치 (prod) 생성? (Git Flow 복잡)
- 수동 승인 단계 추가? (CodePipeline에서 구현 복잡)
```

### 문제 2: buildspec.yml 위치

**현재:**
```
backend/
├── approval-request-service/
│   └── buildspec.yml  # 서비스 폴더 내
├── approval-processing-service/
│   └── buildspec.yml  # 서비스 폴더 내
├── employee-service/
│   └── buildspec.yml  # 서비스 폴더 내
└── notification-service/
    └── buildspec.yml  # 서비스 폴더 내
```

**문제:**
- 4개 파일 중복 (거의 동일한 내용)
- 변경 시 4개 파일 모두 수정 필요
- 일관성 유지 어려움

### 문제 3: kubectl set image만 실행

**buildspec.yml 내용:**
```yaml
post_build:
  commands:
    - docker push $REPOSITORY_URI:$IMAGE_TAG
    - kubectl set image deployment/approval-request-service \
        approval-request-service=$REPOSITORY_URI:$IMAGE_TAG -n erp-dev
    - kubectl rollout status deployment/approval-request-service -n erp-dev
```

**문제:**
- `kubectl set image`는 이미지만 변경
- Deployment의 나머지 설정(replicas, resources, env 등)은 그대로 유지
- Manifests 변경이 반영 안 됨

**올바른 방법:**
```yaml
post_build:
  commands:
    - kubectl apply -f manifests/  # 전체 리소스 배포
```

---

## 3. Manifests 구조 문제

### 문제 1: Plain YAML (하드코딩)

**현재 구조:**
```
manifests/
├── base/
│   ├── configmap.yaml
│   └── secret.yaml
├── approval-request/
│   ├── approval-request-deployment.yaml
│   ├── approval-request-service.yaml
│   └── approval-request-service-hpa.yaml
├── approval-processing/
│   └── ...
├── employee/
│   └── ...
└── notification/
    └── ...
```

**문제:**

#### 1) 환경별 설정 분리 불가능

**현재:**
```yaml
# approval-request-deployment.yaml
spec:
  replicas: 2  # 하드코딩
  image: xxx:latest  # 하드코딩
  resources:
    limits:
      memory: 512Mi  # 하드코딩
```

**개발계와 운영계가 다른 설정 필요:**
- 개발계: replicas=2, memory=512Mi
- 운영계: replicas=5, memory=2Gi

**현재 구조로는 불가능:**
- 파일을 복사해서 manifests-dev/, manifests-prod/ 만들어야 함
- 중복 코드 발생
- 유지보수 어려움

#### 2) 템플릿 재사용 불가능

**현재:**
```
approval-request-deployment.yaml (100줄)
approval-processing-deployment.yaml (100줄)
employee-deployment.yaml (100줄)
notification-deployment.yaml (100줄)
```

**거의 동일한 내용:**
- 차이점: name, image, port, env 정도
- 나머지는 모두 동일 (affinity, securityContext, probes 등)
- **400줄 중 300줄이 중복**

#### 3) 버전 관리 어려움

**현재:**
```bash
kubectl apply -f manifests/
```

**문제:**
- 어떤 버전이 배포되었는지 추적 불가
- 롤백 시 Git 히스토리 확인 필요
- 배포 히스토리 없음
```

### 문제 2: 하드코딩된 값

**base/configmap.yaml:**
```yaml
data:
  MYSQL_HOST: "erp-dev-mysql.cniqqqqiyu1n.ap-northeast-2.rds.amazonaws.com"  # 하드코딩
  MONGODB_URI: "mongodb+srv://erp_user:***@erp-dev-cluster.4fboxqw.mongodb.net/erp"  # 하드코딩
  REDIS_HOST: "erp-dev-redis.jmz0hq.0001.apn2.cache.amazonaws.com"  # 하드코딩
```

**문제:**
- 환경별로 다른 값 필요 (개발계/운영계)
- 현재는 개발계 값만 하드코딩
- 운영계 배포 시 파일 수정 필요

**base/secret.yaml:**
```yaml
stringData:
  MYSQL_USERNAME: "admin"
  MYSQL_PASSWORD: "123456789"  # ⚠️ 평문 저장 (보안 취약)
```

**문제:**
- 비밀번호가 Git에 평문으로 커밋됨
- AWS Secrets Manager 미사용
- 실무에서는 절대 금지

### 문제 3: 이미지 태그 관리

**현재:**
```yaml
# approval-request-deployment.yaml
spec:
  template:
    spec:
      containers:
      - name: approval-request-service
        image: 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-request-service:latest
```

**문제:**
- `latest` 태그 사용
- buildspec.yml이 `kubectl set image`로 커밋 해시 태그로 변경
- Git 파일에는 `latest`로 남아있음
- **Git과 클러스터 불일치**

**올바른 방법:**
```yaml
# Helm values.yaml
services:
  approvalRequest:
    image:
      tag: a1b2c3d  # 구체적 버전
```
- buildspec.yml이 values.yaml 업데이트 후 Git Commit
- Git이 진실

---

## 4. 인프라 구조 문제

### 문제 1: NLB 중복 생성

**현재 상황:**

**Terraform (infrastructure/terraform/dev/erp-dev-APIGateway/nlb/nlb.tf):**
```hcl
# NLB 1개 생성
resource "aws_lb" "nlb" {
  name               = "erp-dev-nlb"
  load_balancer_type = "network"
  ...
}

# Target Group 4개 생성
resource "aws_lb_target_group" "employee" { port = 8081 }
resource "aws_lb_target_group" "approval_request" { port = 8082 }
resource "aws_lb_target_group" "approval_processing" { port = 8083 }
resource "aws_lb_target_group" "notification" { port = 8084 }
```

**Kubernetes (manifests/notification/notification-service.yaml):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: notification-service
spec:
  type: LoadBalancer  # ⚠️ 별도 NLB 자동 생성
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

**TargetGroupBinding (manifests/base/targetgroupbinding.yaml):**
```yaml
# 4개 서비스 모두 Terraform NLB에 연결
- employee-service → erp-dev-employee-nlb-tg
- approval-request-service → erp-dev-approval-req-nlb-tg
- approval-processing-service → erp-dev-approval-proc-nlb-tg
- notification-service → erp-dev-notification-nlb-tg  # ⚠️ 이것도 연결됨!
```

**결과:**
```
Terraform NLB (erp-dev-nlb)
├─ Employee (TargetGroupBinding)
├─ Approval Request (TargetGroupBinding)
├─ Approval Processing (TargetGroupBinding)
└─ Notification (TargetGroupBinding) ← 연결됨

Kubernetes LoadBalancer NLB (자동 생성)
└─ Notification (LoadBalancer) ← 또 연결됨!
```

**문제:**
- **NLB 2개 사용 중** (Terraform 1개 + Kubernetes 1개)
- Notification Service가 **2개 NLB에 동시 연결**
- Kubernetes LoadBalancer NLB는 **사용 안 하고 놀고 있음** (API Gateway는 Terraform NLB 사용)
- 비용 낭비 ($16/월), 일관성 없음

**설계 실수 과정:**
1. 초기: "WebSocket은 지속 연결이 필요하니 LoadBalancer로 설정하자"
2. 나중: "TargetGroupBinding으로 Terraform NLB에도 연결하자"
3. 결과: 중복 연결, 놀고 있는 NLB 생성

**올바른 구조:**
- 모든 Service를 ClusterIP + TargetGroupBinding으로 통일
- NLB 1개로 충분 (WebSocket도 NLB Layer 4 TCP로 처리 가능)

### 문제 2: Lambda 미사용 (하이브리드 구조 미구현)

**현재 구조:**
```
API Gateway (단일 진입점)
  ├─ /employees/*     → VPC Link → NLB → Employee Pods (2)
  ├─ /approvals/*     → VPC Link → NLB → Approval Pods (4) - Kafka
  └─ /notifications/* → VPC Link → NLB → Notification Pods (2) - WebSocket

총 8 Pods (Employee 2 + Approval Request 2 + Approval Processing 2 + Notification 2)
비용: EKS $82.30/월
```

**개선 가능:**
```
API Gateway (단일 진입점)
  ├─ /employees/*     → Lambda (직접 통합, VPC Link 불필요) → RDS Proxy → MySQL
  ├─ /approvals/*     → VPC Link → NLB → Approval Pods (4) - Kafka
  └─ /notifications/* → VPC Link → NLB → Notification Pods (2) - WebSocket

총 6 Pods (Approval Request 2 + Approval Processing 2 + Notification 2)
비용: EKS $61.73 (6 Pods) + Lambda $3 = $64.73 (21% 절감)
```

**Lambda 전환 가능:**
- **Employee Service**: 간단한 CRUD, MySQL 조회만, 실행 시간 200ms

**Lambda 전환 불가:**
- **Notification**: WebSocket 연결 유지 필요 (Lambda는 요청-응답 모델)
- **Approval Services**: Kafka Consumer 장시간 실행 (Lambda 15분 제한 초과)

**왜 구현 못 했나:**
- 14일 기간 제약
- Lambda + RDS Proxy 연결 설정
- API Gateway 라우팅 분기 구현
- 학습 우선순위: Kafka 비동기 메시징

### 문제 3: Kafka Deployment (StatefulSet 아님)

**현재 구조:**
```yaml
# manifests/kafka/kafka-simple.yaml
kind: Deployment  # ⚠️ StatefulSet 아님
spec:
  replicas: 1
  # volumeClaimTemplates 없음 = 메모리만 사용
```

**3가지 문제:**
1. **데이터 영속성 없음**: Pod 재시작 시 메시지 소실
2. **고가용성 없음**: replicas 1
3. **Stateful 애플리케이션을 Deployment로 배포**

**왜 다른 서비스는 Deployment로 괜찮은가?**

| 서비스 | 데이터 저장 | 리소스 | 문제 |
|--------|-----------|--------|------|
| Employee | RDS (외부) | Deployment | ✅ 괜찮음 |
| Approval | MongoDB (외부) | Deployment | ✅ 괜찮음 |
| Notification | ElastiCache (외부) | Deployment | ✅ 괜찮음 |
| Kafka | **Pod 내부** | Deployment | ❌ 문제 |

**StatefulSet으로 구현했다면:**
```yaml
kind: StatefulSet
spec:
  replicas: 3
  volumeClaimTemplates:
  - metadata:
      name: kafka-data
    spec:
      storageClassName: gp3
      resources:
        requests:
          storage: 10Gi
```

**장점:**
- Pod 재시작 시 데이터 보존 (EBS 볼륨)
- 고정 Pod 이름 (kafka-0, kafka-1, kafka-2)
- 순차 생성/삭제 (마스터 보호)

**비용:**
- EBS gp3: $0.08/GB/월
- 10Gi × 3개 = $2.4/월

**왜 이렇게 구현?**
- 학습 목적 (Kafka 비동기 메시징 경험)
- 비용 절감 (MSK $310/월 vs 현재 $0)
- 개발 환경 (메시지 소실 허용)
- 14일 기간 제약

---

## 5. 코드 레벨 문제

### 문제 1: Secret 평문 저장

**manifests/base/secret.yaml:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: erp-secret
  namespace: erp-dev
type: Opaque
stringData:
  MYSQL_USERNAME: "admin"
  MYSQL_PASSWORD: "123456789"  # ⚠️ 평문 저장
```

**문제:**
- 비밀번호가 Git에 평문으로 커밋됨
- 누구나 GitHub에서 확인 가능
- 실무에서는 절대 금지

**올바른 방법:**
```yaml
# AWS Secrets Manager 사용
env:
- name: MYSQL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: erp-secret-from-aws
      key: password
```

### 문제 2: 테스트 부재

**buildspec.yml:**
```yaml
build:
  commands:
    - mvn clean package -DskipTests  # ⚠️ 테스트 건너뜀
```

**문제:**
- 단위 테스트 실행 안 함
- 통합 테스트 없음
- 코드 품질 검증 없음

**CGV와 비교:**
```yaml
# CGV GitLab CI
stages:
  - test
  - sonarqube  # 코드 품질 분석
  - dependency-check  # 취약점 검사
  - build
```

### 문제 3: 보안 설정 부족

**Kafka:**
- TLS/SSL 미적용 (평문 통신)
- 인증 없음 (누구나 접근 가능)

**Network Policy:**
- 미설정 (Pod 간 통신 제한 없음)

**RBAC:**
- 최소 권한 원칙 미적용

---

## 6. 상세 분석: Terraform vs Kubernetes 불일치

### 확인된 문제

#### 1. NLB 중복 생성 (확인됨)

**Terraform (infrastructure/terraform/dev/erp-dev-APIGateway/nlb/nlb.tf):**
```hcl
# NLB 1개 생성
resource "aws_lb" "nlb" {
  name     = "erp-dev-nlb"
  internal = true
  ...
}

# Target Group 4개 생성 (모든 서비스)
resource "aws_lb_target_group" "employee" { port = 8081 }
resource "aws_lb_target_group" "approval_request" { port = 8082 }
resource "aws_lb_target_group" "approval_processing" { port = 8083 }
resource "aws_lb_target_group" "notification" { port = 8084 }  # ← Notification도 포함

# Listener 4개 생성
resource "aws_lb_listener" "notification" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8084
  ...
}
```

**Kubernetes (manifests/notification/notification-service.yaml):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: notification-service
spec:
  type: LoadBalancer  # ⚠️ 별도 NLB 자동 생성
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```

**Kubernetes (manifests/base/targetgroupbinding.yaml):**
```yaml
# Notification도 Terraform NLB에 연결
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: notification-service-tgb
spec:
  serviceRef:
    name: notification-service
    port: 8084
  targetGroupARN: arn:aws:...notification-nlb-tg  # ← Terraform NLB 참조
```

**결과:**
- Terraform NLB (erp-dev-nlb) + Kubernetes LoadBalancer NLB = **NLB 2개**
- Notification Service가 2개 NLB에 동시 연결
- Kubernetes LoadBalancer NLB는 사용 안 함 (API Gateway는 Terraform NLB 사용)

#### 2. 다른 서비스는 올바름 (확인됨)

**Employee, Approval Request, Approval Processing:**
```yaml
# Service: ClusterIP
apiVersion: v1
kind: Service
spec:
  type: ClusterIP  # ✅ 올바름

# TargetGroupBinding: Terraform NLB 연결
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
spec:
  targetGroupARN: arn:aws:...  # ✅ 올바름
```

#### 3. buildspec.yml 위치 (확인됨)

**현재:**
```
backend/
├── approval-request-service/buildspec.yml
├── approval-processing-service/buildspec.yml
├── employee-service/buildspec.yml
└── notification-service/buildspec.yml
```

**내용:**
```yaml
post_build:
  commands:
    - kubectl set image deployment/xxx xxx=$REPOSITORY_URI:$IMAGE_TAG -n erp-dev
    # ⚠️ 이미지만 변경, Manifests 변경 반영 안 됨
```

#### 4. Kafka Deployment (확인됨)

**manifests/kafka/kafka-simple.yaml:**
```yaml
kind: Deployment  # ⚠️ StatefulSet 아님
spec:
  replicas: 1
  # volumeClaimTemplates 없음
```

**문제:**
- 데이터 영속성 없음
- Pod 재시작 시 메시지 소실

#### 5. Secret 평문 (확인됨)

**manifests/base/secret.yaml:**
```yaml
stringData:
  MYSQL_USERNAME: "admin"
  MYSQL_PASSWORD: "123456789"  # ⚠️ 평문
```

---

## 7. 재구축 단계별 가이드

### 전제 조건

**현재 동작하는 환경:**
1. Terraform으로 인프라 배포 완료 (VPC, EKS, RDS, NLB 등)
2. Kubernetes Manifests 배포 완료 (Deployment, Service, HPA 등)
3. CodePipeline 수동 생성 완료 (4개)
4. Git Push 시 자동 배포 동작 중

**목표:**
- Helm Chart 도입
- 단일 buildspec.yml
- NLB 중복 제거
- Git이 진실

---

### Phase 0: 백업 및 준비 (30분)

#### Step 0-1: 현재 상태 백업

```bash
# 1. Kubernetes 리소스 백업
kubectl get all -n erp-dev -o yaml > backup-k8s-$(date +%Y%m%d).yaml

# 2. ConfigMap, Secret 백업
kubectl get configmap,secret -n erp-dev -o yaml > backup-config-$(date +%Y%m%d).yaml

# 3. TargetGroupBinding 백업
kubectl get targetgroupbinding -n erp-dev -o yaml > backup-tgb-$(date +%Y%m%d).yaml

# 4. Git 커밋 (현재 상태 저장)
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project
git add .
git commit -m "Backup before Helm migration"
git tag backup-before-helm
```

#### Step 0-2: 브랜치 생성

```bash
# 재구축용 브랜치 생성
git checkout -b helm-migration

# 작업 중 main 브랜치는 그대로 유지
# 문제 발생 시 git checkout main으로 복구 가능
```

#### Step 0-3: 도구 설치 확인

```bash
# Helm 설치 확인
helm version
# 없으면: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# yq 설치 확인 (YAML 파싱용)
yq --version
# 없으면: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq
```

---

### Phase 1: Helm Chart 생성 (2시간)

#### Step 1-1: Helm Chart 구조 생성 (10분)

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project

# Helm Chart 폴더 생성
mkdir -p helm-chart/templates

# Chart.yaml 생성
cat > helm-chart/Chart.yaml << 'EOF'
apiVersion: v2
name: erp-microservices
description: ERP Microservices Helm Chart
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: ERP Team
EOF
```

#### Step 1-2: values-dev.yaml 작성 (30분)

**파일 생성:**
```bash
cat > helm-chart/values-dev.yaml << 'EOF'
# 여기에 values-dev.yaml 내용 작성 (다음 단계에서 제공)
EOF
```

**내용은 별도 파일로 제공 예정**

#### Step 1-3: templates/ 작성 (1시간)

**생성할 템플릿:**
1. `templates/namespace.yaml`
2. `templates/configmap.yaml`
3. `templates/secret.yaml`
4. `templates/deployment.yaml` (4개 서비스 통합)
5. `templates/service.yaml` (4개 서비스 통합)
6. `templates/hpa.yaml` (4개 서비스 통합)
7. `templates/targetgroupbinding.yaml` (4개 서비스 통합)
8. `templates/kafka.yaml`

**각 템플릿 내용은 별도 파일로 제공 예정**

#### Step 1-4: 테스트 (20분)

```bash
# Dry-run으로 생성될 리소스 확인
cd helm-chart
helm template . -f values-dev.yaml > test-output.yaml

# 생성된 YAML 확인
cat test-output.yaml

# 문법 오류 확인
helm lint . -f values-dev.yaml
```

---

### Phase 2: Notification Service 수정 (30분)

#### Step 2-1: LoadBalancer 제거

**현재 문제:**
- `manifests/notification/notification-service.yaml`이 LoadBalancer로 설정됨
- Helm Chart에서는 ClusterIP로 변경 필요

**Helm Chart에서 이미 해결됨:**
```yaml
# helm-chart/templates/service.yaml
{{- range $key, $service := .Values.services }}
spec:
  type: ClusterIP  # ← 모든 서비스 ClusterIP
{{- end }}
```

**기존 manifests/ 폴더는 삭제 예정이므로 별도 작업 불필요**

#### Step 2-2: 기존 LoadBalancer NLB 삭제 (배포 후)

```bash
# Helm 배포 후 확인
kubectl get svc -n erp-dev

# LoadBalancer 타입 Service가 있으면 삭제
kubectl delete svc notification-service -n erp-dev

# Helm으로 재생성 (ClusterIP)
helm upgrade --install erp-microservices helm-chart/ -f helm-chart/values-dev.yaml -n erp-dev
```

---

### Phase 3: buildspec.yml 통합 (1시간)

#### Step 3-1: 루트에 buildspec.yml 생성

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project

# 기존 buildspec.yml 백업
mkdir -p backup-buildspec
cp backend/*/buildspec.yml backup-buildspec/

# 루트에 새 buildspec.yml 생성
cat > buildspec.yml << 'EOF'
# 내용은 별도 파일로 제공 예정
EOF
```

#### Step 3-2: 기존 buildspec.yml 삭제

```bash
# 서비스별 buildspec.yml 삭제
rm backend/approval-request-service/buildspec.yml
rm backend/approval-processing-service/buildspec.yml
rm backend/employee-service/buildspec.yml
rm backend/notification-service/buildspec.yml
```

#### Step 3-3: Git 커밋

```bash
git add .
git commit -m "Add Helm Chart and unified buildspec.yml"
```

---

### Phase 4: CodePipeline 재생성 (30분)

#### Step 4-1: 기존 CodePipeline 삭제

**AWS Console에서:**
1. CodePipeline 콘솔 접속
2. 4개 파이프라인 삭제:
   - `erp-approval-request-pipeline`
   - `erp-approval-processing-pipeline`
   - `erp-employee-pipeline`
   - `erp-notification-pipeline`

**또는 CLI:**
```bash
aws codepipeline delete-pipeline --name erp-approval-request-pipeline --region ap-northeast-2
aws codepipeline delete-pipeline --name erp-approval-processing-pipeline --region ap-northeast-2
aws codepipeline delete-pipeline --name erp-employee-pipeline --region ap-northeast-2
aws codepipeline delete-pipeline --name erp-notification-pipeline --region ap-northeast-2
```

#### Step 4-2: 단일 CodePipeline 생성

**AWS Console에서:**
1. CodePipeline 콘솔 → "파이프라인 생성"
2. 파이프라인 이름: `erp-unified-pipeline`
3. Source:
   - Provider: GitHub (Version 2)
   - Repository: `erp-project`
   - Branch: `helm-migration` (테스트용, 나중에 main으로 변경)
   - Trigger: Push events
4. Build:
   - Provider: AWS CodeBuild
   - Project name: `erp-unified-build` (새로 생성)
   - Buildspec: `buildspec.yml` (루트)
5. Deploy: Skip (buildspec.yml에서 처리)

#### Step 4-3: CodeBuild 프로젝트 생성

**설정:**
- Project name: `erp-unified-build`
- Source: CodePipeline
- Environment:
  - Image: `aws/codebuild/standard:7.0`
  - Privileged: ✅ (Docker 빌드 필요)
  - Service role: 기존 `codebuild-role` 사용
- Buildspec: `buildspec.yml`

---

### Phase 5: 배포 및 검증 (1시간)

#### Step 5-1: 기존 리소스 삭제

```bash
# 1. 기존 Deployment 삭제 (Helm이 재생성)
kubectl delete deployment -n erp-dev --all

# 2. 기존 Service 삭제 (LoadBalancer 제거)
kubectl delete svc -n erp-dev --all

# 3. 기존 HPA 삭제
kubectl delete hpa -n erp-dev --all

# 4. ConfigMap, Secret은 유지 (Helm이 업데이트)
```

#### Step 5-2: Helm 배포

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project

# Helm 배포
helm upgrade --install erp-microservices helm-chart/ \
  -f helm-chart/values-dev.yaml \
  -n erp-dev \
  --create-namespace \
  --wait \
  --timeout 5m

# 배포 확인
helm list -n erp-dev
kubectl get pods -n erp-dev
kubectl get svc -n erp-dev
```

#### Step 5-3: 동작 확인

```bash
# 1. Pod 상태 확인
kubectl get pods -n erp-dev -o wide

# 2. Service 확인 (모두 ClusterIP여야 함)
kubectl get svc -n erp-dev

# 3. TargetGroupBinding 확인
kubectl get targetgroupbinding -n erp-dev

# 4. NLB Target Health 확인 (AWS Console)
# EC2 → Load Balancers → erp-dev-nlb → Target Groups
# 모든 Target이 healthy여야 함

# 5. API Gateway 테스트
curl https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/api/employees
```

#### Step 5-4: Git Push 테스트

```bash
# 1. 코드 변경 (간단한 수정)
echo "// Test" >> backend/employee-service/src/main/java/com/erp/employee/EmployeeController.java

# 2. Git Push
git add .
git commit -m "Test: Trigger pipeline"
git push origin helm-migration

# 3. CodePipeline 확인 (AWS Console)
# - Source Stage: 성공
# - Build Stage: 진행 중
# - buildspec.yml 로그 확인

# 4. 배포 확인
kubectl get pods -n erp-dev -w
helm history erp-microservices -n erp-dev
```

---

### Phase 6: main 브랜치 병합 (30분)

#### Step 6-1: 테스트 완료 후 병합

```bash
# helm-migration 브랜치에서 모든 테스트 완료 확인

# main 브랜치로 전환
git checkout main

# helm-migration 병합
git merge helm-migration

# Push
git push origin main
```

#### Step 6-2: CodePipeline 브랜치 변경

**AWS Console에서:**
1. CodePipeline → `erp-unified-pipeline` → Edit
2. Source Stage → Branch: `helm-migration` → `main`
3. Save

#### Step 6-3: 최종 확인

```bash
# main 브랜치에서 코드 변경
echo "// Final test" >> backend/employee-service/src/main/java/com/erp/employee/EmployeeController.java

git add .
git commit -m "Final test on main branch"
git push origin main

# CodePipeline 자동 트리거 확인
# 배포 완료 확인
```

---

### Phase 7: 정리 및 문서화 (30분)

#### Step 7-1: 불필요한 파일 삭제

```bash
# 1. 기존 manifests/ 폴더 삭제 (Helm Chart로 대체)
git rm -r manifests/
git commit -m "Remove old manifests (replaced by Helm Chart)"

# 2. backup-buildspec/ 폴더 삭제
rm -rf backup-buildspec/

# 3. helm-migration 브랜치 삭제 (선택)
git branch -d helm-migration
git push origin --delete helm-migration
```

#### Step 7-2: README 업데이트

```bash
# README.md 수정
# - Helm Chart 사용 명시
# - 배포 방법 업데이트
# - buildspec.yml 위치 변경 설명
```

#### Step 7-3: CURRENT_STATUS_AND_PROBLEMS.md 업데이트

```bash
# 해결된 문제 체크
# - ✅ NLB 중복 제거
# - ✅ 단일 buildspec.yml
# - ✅ Helm Chart 도입
# - ✅ Git이 진실
```

---

## 8. 트러블슈팅

### 문제 1: Helm 배포 실패

**증상:**
```
Error: INSTALLATION FAILED: unable to build kubernetes objects
```

**해결:**
```bash
# 템플릿 문법 확인
helm lint helm-chart/ -f helm-chart/values-dev.yaml

# Dry-run으로 생성될 YAML 확인
helm template helm-chart/ -f helm-chart/values-dev.yaml > test.yaml
kubectl apply -f test.yaml --dry-run=client
```

### 문제 2: Pod가 Pending 상태

**증상:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
employee-service-xxx                    0/2     Pending   0          5m
```

**해결:**
```bash
# Pod 상세 확인
kubectl describe pod employee-service-xxx -n erp-dev

# Node 리소스 확인
kubectl top nodes

# 원인: Node 리소스 부족
# 해결: EKS Node Group 확장 또는 Pod resources 조정
```

### 문제 3: TargetGroupBinding 연결 안 됨

**증상:**
```
kubectl get targetgroupbinding -n erp-dev
NAME                              AGE
employee-service-tgb              5m
# Status: Failed
```

**해결:**
```bash
# TargetGroupBinding 상세 확인
kubectl describe targetgroupbinding employee-service-tgb -n erp-dev

# 원인: Target Group ARN 불일치
# 해결: values-dev.yaml의 targetGroupArn 확인 및 수정
```

### 문제 4: CodeBuild 권한 오류

**증상:**
```
Error: User is not authorized to perform: eks:DescribeCluster
```

**해결:**
```bash
# CodeBuild IAM Role에 EKS 권한 추가
# Terraform: infrastructure/terraform/dev/erp-dev-IAM/codebuild-role/
# Policy: eks:DescribeCluster, eks:ListClusters
```

---

## 9. 예상 소요 시간

| Phase | 작업 | 소요 시간 |
|-------|------|----------|
| Phase 0 | 백업 및 준비 | 30분 |
| Phase 1 | Helm Chart 생성 | 2시간 |
| Phase 2 | Notification Service 수정 | 30분 |
| Phase 3 | buildspec.yml 통합 | 1시간 |
| Phase 4 | CodePipeline 재생성 | 30분 |
| Phase 5 | 배포 및 검증 | 1시간 |
| Phase 6 | main 브랜치 병합 | 30분 |
| Phase 7 | 정리 및 문서화 | 30분 |
| **합계** | | **7시간** |

**실제 소요 시간: 1~2일 (휴식 포함)**

---

## 10. 체크리스트

### 재구축 전

- [ ] 현재 상태 백업 완료
- [ ] Git 태그 생성 (`backup-before-helm`)
- [ ] 브랜치 생성 (`helm-migration`)
- [ ] Helm, yq 설치 확인

### Helm Chart 생성

- [ ] Chart.yaml 작성
- [ ] values-dev.yaml 작성
- [ ] templates/ 8개 파일 작성
- [ ] `helm lint` 통과
- [ ] `helm template` 출력 확인

### buildspec.yml 통합

- [ ] 루트에 buildspec.yml 생성
- [ ] 변경 감지 로직 작성
- [ ] Helm 설치 명령 추가
- [ ] values.yaml 업데이트 로직 추가
- [ ] 기존 buildspec.yml 삭제

### CodePipeline 재생성

- [ ] 기존 4개 파이프라인 삭제
- [ ] 단일 파이프라인 생성 (`erp-unified-pipeline`)
- [ ] CodeBuild 프로젝트 생성 (`erp-unified-build`)
- [ ] IAM 권한 확인

### 배포 및 검증

- [ ] 기존 리소스 삭제
- [ ] Helm 배포 성공
- [ ] Pod 모두 Running
- [ ] Service 모두 ClusterIP
- [ ] TargetGroupBinding 연결 확인
- [ ] NLB Target Health 확인
- [ ] API Gateway 테스트 성공
- [ ] Git Push 테스트 성공

### 최종 정리

- [ ] main 브랜치 병합
- [ ] CodePipeline 브랜치 변경
- [ ] 불필요한 파일 삭제
- [ ] README 업데이트
- [ ] CURRENT_STATUS_AND_PROBLEMS.md 업데이트

---

**"단계별로 천천히 진행하면 반드시 성공합니다. 각 단계마다 확인하고 다음으로 넘어가세요."**

---

## 결론

**현재 ERP 프로젝트는 포트폴리오에 올리기 부끄러운 수준입니다.**

**핵심 문제:**
1. ❌ 서비스별 독립 파이프라인 (의존성 무시)
2. ❌ Manifests 변경이 배포 안 됨 (kubectl set image만 실행)
3. ❌ Git이 진실이 아님 (Drift Detection 없음)
4. ❌ 환경 분리 불가능 (Plain YAML 하드코딩)
5. ❌ NLB 중복 생성 (일관성 없음)
6. ❌ Lambda 미사용 (비용 최적화 기회 놓침)
7. ❌ Kafka Deployment (데이터 영속성 없음)
8. ❌ Secret 평문 저장 (보안 취약)

**재구축 필요성:**
- 2~3일 투자로 포트폴리오 가치 10배 상승
- 면접에서 자신감 있게 설명 가능
- CGV 경험 + AWS 네이티브 도구 = 완벽한 스토리

**다음 단계:**
- Helm Chart 전환
- 단일 buildspec.yml
- 문제 해결 (NLB, Kafka, Secret)

---

**"실패를 인정하고 재구축하는 것이 진짜 실력입니다."**
