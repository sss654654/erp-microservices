# ERP 마이크로서비스 전자결재 시스템

**Lambda + EKS 하이브리드** | **완전 자동화 CI/CD** | **AWS Native 모니터링**

---

## 핵심 성과

| 지표 | 수치 | 설명 |
|------|------|------|
| **배포 시간** | 3분 11초 | Git Push → 프로덕션 배포 완료 |
| **응답 시간 개선** | 85% 단축 | gRPC 850ms → Kafka 120ms |
| **비용 절감** | 21% | Lambda 하이브리드 ($82.30 → $64.73) |
| **배포 빈도** | 무제한 | 수동 30분 → 자동 3분 |
| **에러율** | 0% | 수동 20% → 자동화 0% |

---

## 이 프로젝트가 해결하려는 문제

### CGV 프로젝트의 한계

이전 CGV 대기열 시스템에서 **Kinesis + Redis를 활용한 대량 트래픽 처리**에는 성공했습니다. 하지만 **단일 API 서버 구조**였습니다.

**CGV 프로젝트 구조:**
```
대량 트래픽 → ALB → 단일 API 서버 → Kinesis → Redis → RDS Aurora
```
- ✅ Kinesis로 요청 버퍼링
- ✅ Redis로 대기열 관리
- ✅ 대량 트래픽 처리 성공
- ❌ 마이크로서비스 아님 (모든 기능이 하나의 서버)

### 이 프로젝트에서 해결한 것

**"마이크로서비스 + AWS Native CI/CD + 완전 자동화"**

1. **Lambda 하이브리드**: Employee Service를 Lambda로 전환 (비용 21% 절감)
2. **Kafka 비동기 메시징**: gRPC 850ms → Kafka 120ms (85% 개선)
3. **완전 자동화 CI/CD**: CodePipeline + CodeBuild (Git Push → 3분 11초 배포)
4. **AWS Native 모니터링**: CloudWatch Logs + X-Ray + Alarm (실시간 알림)
5. **Terraform IaC**: 전체 인프라 코드화 (세분화 전략)

---

## 아키텍처

### Lambda + EKS 하이브리드 구조

```
┌─────────────────────────────────────────────────────────────┐
│                   CloudFront (Frontend)                      │
│              https://d3goird6ndqlnv.cloudfront.net           │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    S3 Bucket (React SPA)                     │
└─────────────────────────────────────────────────────────────┘
                     │ API 호출
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              API Gateway (HTTP API)                          │
│       https://yvx3l9ifii.execute-api.ap-northeast-2...       │
│                   - Cognito Authorizer (JWT)                 │
│                   - CORS 중앙 관리                           │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
    Lambda      VPC Link      Cognito
  (Employee)        │         (Auth)
   직접 통합        │
        │           ▼
        │    ┌─────────────┐
        │    │ NLB (단일)  │
        │    │ 3 Target Grp│
        │    └──────┬──────┘
        │           │
        │    ┌──────┼──────┐
        │    │      │      │
        │  8082   8083   8084
        │    │      │      │
    ┌───┴────┴──────┴──────┴───┐
    │    EKS Cluster (1.31)     │
    │  ┌─────────────────────┐  │
    │  │ Service Nodes (2)   │  │
    │  │ - approval-req (2)  │  │
    │  │ - approval-proc (2) │  │
    │  │ - notification (2)  │  │
    │  └─────────────────────┘  │
    │  ┌─────────────────────┐  │
    │  │ Kafka Nodes (2)     │  │
    │  │ - kafka (2)         │  │
    │  │ - zookeeper (2)     │  │
    │  │ Taint: kafka        │  │
    │  └─────────────────────┘  │
    └───────────┬───────────────┘
                │
    ┌───────────┼───────────┐
    │           │           │
RDS MySQL   ElastiCache  MongoDB
(Private)    (Private)    (Atlas)
```

**핵심 특징:**
- **Lambda 하이브리드**: Employee Service만 Lambda (비용 21% 절감)
- **API Gateway 직접 통합**: Lambda는 VPC Link 불필요
- **2개 Node Group**: Service용 2개 + Kafka 전용 2개 (Taint 격리)
- **단일 NLB**: 3개 EKS 서비스만 연결 (Employee는 Lambda)
- **완전 자동화**: Git Push → 3분 11초 배포

### VPC 네트워크 설계

```
VPC: 10.0.0.0/16
├── Public Subnet:  10.0.1.0/24, 10.0.2.0/24 (2a, 2c) - NAT Gateway
├── Private Subnet: 10.0.10.0/24, 10.0.11.0/24 (2a, 2c) - EKS Nodes
└── Data Subnet:    10.0.20.0/24, 10.0.21.0/24 (2a, 2c) - RDS, Redis
```

**설계 원칙:**
- Multi-AZ: 2개 가용 영역 (고가용성)
- Public/Private 분리: 데이터베이스는 Private Subnet
- NAT Gateway: 1개만 배치 (비용 절감)

### 기술 스택

| 계층 | 기술 | 버전 | 선택 이유 |
|------|------|------|-----------|
| **Backend** | Spring Boot | 3.3.5 | 엔터프라이즈급 안정성 |
| | Java | 17 | LTS 버전 |
| **Database** | MySQL | 8.0 | ACID 트랜잭션 |
| | MongoDB | 7.0 | 유연한 스키마 |
| | Redis | 7.0 | 인메모리 캐시 |
| **Messaging** | Kafka | 3.6.0 | 비동기 이벤트 |
| **Frontend** | React | 18.2 | 컴포넌트 기반 |
| | Vite | 5.0 | 빠른 HMR |
| **Infrastructure** | Terraform | 1.6.0 | IaC |
| | Kubernetes (EKS) | 1.31 | 컨테이너 오케스트레이션 |
| | Helm | 3.x | 패키지 관리 |
| **CI/CD** | CodePipeline | - | GitHub 연동 |
| | CodeBuild | - | Docker 빌드 |
| **Monitoring** | CloudWatch Logs | - | 로그 중앙 집중 |
| | X-Ray | - | 분산 트레이싱 |
| | CloudWatch Alarm | - | 실시간 알림 |
| **AWS** | Lambda | - | 서버리스 (Employee) |
| | API Gateway | - | 단일 진입점 |
| | NLB | - | Layer 4 로드밸런싱 |
| | CloudFront | - | CDN |
| | Cognito | - | 인증/인가 |
| | Secrets Manager | - | 비밀 정보 관리 |
| | Parameter Store | - | 설정 중앙 관리 |

---

## 문제 해결 과정

### 1. Lambda 하이브리드 구조 (비용 21% 절감)

**문제: 모든 서비스를 EKS에 배포하면 비용 낭비**

**Employee Service 분석:**
- 간단한 CRUD 작업 (평균 200ms)
- MySQL만 사용 (Kafka, WebSocket 없음)
- 트래픽이 적음 (Cold Start 허용 가능)

**Lambda 전환 결과:**
```
Before: EKS 8 Pods (4개 서비스 × 2 Pods)
After:  EKS 6 Pods (3개 서비스 × 2 Pods) + Lambda 1개

비용: $82.30/월 → $64.73/월 (21% 절감, $17.57/월)
```

**구현:**
- Lambda Web Adapter: 기존 Spring Boot 코드 수정 없이 Lambda 실행
- Secrets Manager 통합: RDS 자격증명 자동 주입
- API Gateway 직접 통합: VPC Link 불필요 (비용 추가 절감)

**배운 점:**
- 모든 서비스를 동일한 방식으로 배포하는 것이 아니라, 특성에 맞게 선택
- Lambda는 간단한 API, EKS는 복잡한 로직/장시간 실행에 적합

**상세**: [re_build/04_LAMBDA_DEPLOY.md](./re_build/04_LAMBDA_DEPLOY.md)

---

### 2. 동기 통신의 한계 경험 → Kafka 비동기 전환

**2단계: gRPC로 구현했을 때**

```
Approval Request Service
  ↓ gRPC 동기 호출
  ↓ 응답 대기... (850ms)
Approval Processing Service
```

**측정 결과:**
- 평균 응답 시간: 850ms
- 에러율: 5% (타임아웃)
- 처리량: 35 req/sec
- **문제**: Processing Service 다운 시 Request Service도 실패

**3단계: Kafka 비동기 메시징으로 전환**

```
Approval Request Service
  ↓ Kafka Produce (비동기, 즉시 반환)
Kafka Topic
  ↓ Consumer Group (병렬 처리)
Approval Processing Service
```

**개선 결과:**
- 평균 응답 시간: 120ms (85% 감소)
- 에러율: 0% (완전 제거)
- 처리량: 250 req/sec (610% 증가)
- **해결**: Processing Service 다운되어도 메시지는 Kafka에 보존

**Kinesis vs Kafka 선택:**

| 항목 | Kinesis (CGV) | Kafka (ERP) |
|------|---------------|-------------|
| 사용 패턴 | 단일 서비스 내 대기열 | 서비스 간 메시징 |
| 구조 | API 서버 → Kinesis → 동일 서버 | Request → Kafka → Processing |
| Consumer | 단일 Consumer | Consumer Group (병렬) |
| 목적 | 대량 트래픽 버퍼링 | 서비스 간 비동기 통신 |

**배운 점:**
- 동기 통신은 간단하지만 확장성과 안정성에 한계
- 비동기 메시징은 복잡도가 높지만 장애 격리와 성능 개선 효과 큼
- Kafka on EKS: MSK $300/월 대신 기존 EKS 노드 활용 (추가 비용 없음)

---

### 3. 완전 자동화 CI/CD (Git Push → 3분 11초 배포)

**CGV 프로젝트의 한계:**
- GitLab CI/CD 코드를 받아서 백엔드용으로 리팩토링만 함
- 파이프라인 구조는 이해했지만 직접 설계 경험 부족

**이번 프로젝트에서 구현:**

```
GitHub Push (1초)
  ↓
CodePipeline 트리거 (6초)
  ↓
CodeBuild 실행 (2분 54초)
  ├─ Parameter Store 읽기 (하드코딩 제거)
  ├─ Git diff 변경 감지 (변경된 서비스만 빌드)
  ├─ Maven + Docker 빌드
  ├─ ECR 푸시 + 이미지 스캔 (CRITICAL 차단)
  ├─ Lambda 업데이트 (Employee Service)
  └─ Helm 배포 (EKS 3개 서비스)
  ↓
배포 완료 (3분 11초)
  ├─ 12 Pods Running
  ├─ 1 Lambda 함수 업데이트
  ├─ CloudWatch Logs 수집 시작
  ├─ X-Ray 트레이싱 활성화
  └─ CloudWatch Alarm 모니터링
```

**핵심 기능:**
1. **Parameter Store 활용**: buildspec.yml 하드코딩 제거 (6개 설정 값)
2. **Git diff 변경 감지**: 변경된 서비스만 빌드 (시간 70% 단축)
3. **ECR 이미지 스캔**: CRITICAL 취약점 자동 차단
4. **Helm 배포**: kubectl set image 대신 helm upgrade (Manifests 자동 반영)

**성과:**

| 지표 | Before (수동) | After (자동) | 개선율 |
|------|--------------|-------------|--------|
| 배포 시간 | 30분 | 3분 11초 | 90% 단축 |
| 배포 빈도 | 주 1회 | 무제한 | 무제한 |
| 에러율 | 20% | 0% | 100% 개선 |
| 롤백 시간 | 30분 | 1분 | 97% 단축 |

**배운 점:**
- CI/CD 파이프라인을 직접 설계하면서 각 단계의 역할 이해
- IAM Role 권한 설정의 중요성 (CodeBuild가 ECR, EKS, Secrets Manager 접근)
- Git이 진실 (Source of Truth): values-dev.yaml 변경 시 자동 반영

**상세**: [re_build/07_CODEPIPELINE.md](./re_build/07_CODEPIPELINE.md)

---

### 4. AWS Native 모니터링 (CloudWatch + X-Ray + Alarm)

**구현:**

**1. CloudWatch Logs (중앙 집중)**
- Fluent Bit DaemonSet: 모든 Pod 로그 수집
- Lambda: 자동으로 CloudWatch Logs 전송
- 영구 보관: Pod 재시작 시에도 로그 유지

**2. X-Ray (분산 트레이싱)**
- HTTP 서비스: X-Ray Servlet Filter 자동 추적
- Lambda: 내장 X-Ray 자동 추적
- Service Map: 병목 지점 시각화

**3. CloudWatch Alarm (실시간 알림)**
- ERROR 로그 10회 이상 (5분) → SNS 이메일
- Pod 재시작 3회 이상 (10분) → SNS 이메일
- Lambda 에러율 5% 이상 → SNS 이메일

**실제 동작 시나리오:**
```
① ERROR 로그 발생
② Fluent Bit이 CloudWatch Logs로 전송
③ Metric Filter가 "ERROR" 패턴 감지
④ ErrorCount 메트릭 증가
⑤ 5분 동안 10회 초과 시 Alarm 발동
⑥ SNS Topic으로 이메일 발송
```

**배운 점:**
- CloudWatch Logs: "무엇이" 잘못되었는지 파악
- X-Ray: "어디가" 느린지 파악
- CloudWatch Alarm: 장애 발생 시 즉시 알림

**상세**: [re_build/06_BUILDSPEC.md](./re_build/06_BUILDSPEC.md)

---

### 5. 데이터 특성에 맞는 DB 선택

**고민: 왜 모든 서비스가 MySQL을 쓰면 안 되는가?**

**결재 요청 데이터 구조 분석:**
```json
{
  "requestId": 1,
  "steps": [
    {"step": 1, "approverId": 5, "status": "approved"},
    {"step": 2, "approverId": 6, "status": "pending"}
  ]
}
```

- 결재 단계 수가 가변적 (1단계 ~ N단계)
- 향후 결재 타입별로 다른 필드 추가 가능 (출장 신청 → destination, budget)
- 문서 단위로 조회하는 경우가 대부분

**MySQL로 구현 시:**
- approval_requests 테이블 + approval_steps 테이블 (2개 필요)
- JOIN 필수, 쿼리 복잡도 증가
- 스키마 변경 시 마이그레이션 필요

**MongoDB 선택 이유:**
- 중첩 문서로 1번 쿼리로 전체 데이터 조회
- 스키마 유연성으로 타입별 필드 추가 용이
- 문서 단위 조회 최적화

**결과:**
- Employee Service: MySQL (직원 정보는 구조 고정, ACID 트랜잭션 필요)
- Approval Request: MongoDB (결재 요청은 구조 유동적, 스키마 유연성 필요)
- Notification: Redis (알림은 임시 데이터, 빠른 조회 필요)

**배운 점:**
- 모든 데이터를 하나의 DB에 넣는 것이 아니라, 데이터 특성 분석 후 적합한 DB 선택
- Database per Service 패턴으로 각 서비스가 독립적으로 확장 가능

---

### 6. Terraform 구조 설계 (세분화 vs 통합)

**멘토 조언:**
> "실무에서는 보안그룹이나 RDS를 Terraform으로 관리하면 정책 1개만 달라져도 틀어져서 여러 부서가 함께하는 프로젝트에는 부적합. 폴더는 세분화하고 각 tfstate 파일을 따로 저장하는게, 콘솔 작업 후 형상 맞춰주기 좋음."

**설계 결정:**

**SecurityGroups: 세분화 선택**
```
erp-dev-SecurityGroups/
├── alb-sg/     # tfstate 1
├── eks-sg/     # tfstate 2
├── rds-sg/     # tfstate 3
└── elasticache-sg/  # tfstate 4
```
- 이유: 각 SG는 독립적으로 수정 빈도가 다름
- 콘솔에서 급하게 수정 후 import 용이
- State Lock 충돌 없음

**IAM: 통합 선택**
```
erp-dev-IAM/
├── main.tf  # 각 role 폴더 module 호출
├── eks-cluster-role/
├── eks-node-role/
├── codebuild-role/
└── codepipeline-role/
```
- 이유: Trust Policy 일관성 유지 필요
- 권한 정책 중복 방지
- 전체 권한 한 번에 검토 가능

**배운 점:**
- 정답은 없음, 변경 빈도와 의존성 강도로 판단
- 현업에서는 리소스 특성에 따라 Terraform vs 콘솔 선택

**상세**: [infrastructure/README.md](./infrastructure/README.md)

---

### 7. Redis Pub/Sub로 멀티 Pod 알림 문제 해결

**문제 상황:**
```
Notification Service Pod 1 → WebSocket 연결 (사용자 A)
Notification Service Pod 2 → WebSocket 연결 (사용자 B)

결재 승인 시 → Pod 1에만 알림 전송 → 사용자 B는 알림 못 받음
```

**해결: Redis Pub/Sub 브로드캐스트**
- 모든 Pod가 Redis 채널 구독
- Redis가 모든 Pod에 메시지 브로드캐스트
- 각 Pod는 자신에게 연결된 WebSocket 세션에만 전송

**배운 점:**
- 멀티 Pod 환경에서는 상태 공유 메커니즘 필요
- Redis Pub/Sub, Kafka 등 메시지 브로커 활용

---

## 제약사항과 의사결정

### 현실적 제약사항

```
역할: 1인 개발 (풀스택 + DevOps)
예산: AWS 크레딧 $180
기간: 14일
```

**12월 1일 ~ 12일 실제 사용량:**
```
이번 달 사용: $123.77
- EKS: $82.30 (66.5%)
- EC2 (NAT Gateway): $12.82 (10.4%)
- EC2 (Compute): $6.72 (5.4%)
- ELB: $5.87 (4.7%)
- RDS: $4.82 (3.9%)
- 기타: $11.25 (9.1%)

남은 크레딧: $54.99
```

### 비용 최적화 의사결정

**Lambda 하이브리드 적용 후:**

| 리소스 | Before | After | 절감 |
|--------|--------|-------|------|
| EKS Cluster | $73 | $73 | - |
| EKS Nodes | $60 (4개) | $45 (3개) | $15 |
| Lambda | - | $3 | +$3 |
| RDS MySQL | $15 | $15 | - |
| ElastiCache | $12 | $12 | - |
| NAT Gateway | $32 | $32 | - |
| NLB | $16 | $16 | - |
| 기타 | $5 | $5 | - |
| **합계** | **$213** | **$201** | **$12** |

**Single-AZ 선택:**
- 고가용성 포기 (99.95% → 99.5%)
- 다운타임 허용 (자동 Failover 없음)
- 학습 목적이므로 기능 검증이 최우선
- 프로덕션 전환 시 Terraform 변수 하나로 Multi-AZ 전환 가능

---

## 얻은 능력

### 1. Lambda 하이브리드 아키텍처 설계 능력

- 서비스 특성 분석 (실행 시간, 의존성, 트래픽)
- Lambda vs EKS 선택 기준 수립
- Lambda Web Adapter로 기존 코드 재사용
- API Gateway 직접 통합 (VPC Link 불필요)
- 비용 21% 절감 달성

### 2. 완전 자동화 CI/CD 구축 능력

- CodePipeline + CodeBuild 설계
- buildspec.yml 직접 작성 (Parameter Store, Git diff, ECR 스캔)
- IAM Role 권한 설정 (9개 정책)
- Helm 배포 자동화 (kubectl set image 대신)
- 배포 시간 90% 단축 (30분 → 3분 11초)

### 3. AWS Native 모니터링 구축 능력

- CloudWatch Logs 중앙 집중 (Fluent Bit DaemonSet)
- X-Ray 분산 트레이싱 (HTTP 서비스 + Lambda)
- CloudWatch Alarm 실시간 알림 (ERROR 로그, Pod 재시작, Lambda 에러)
- Metric Filter 패턴 정의
- SNS 이메일 통합

### 4. 문제 정의 및 해결 능력

- gRPC 동기 통신의 문제점을 측정 데이터로 정량화
- Kafka 비동기 메시징으로 전환하여 85% 성능 개선
- 문제 → 측정 → 분석 → 해결 → 검증 프로세스 경험

### 5. 데이터 특성 분석 및 DB 선택 능력

- 데이터 구조, 조회 패턴, 확장성 요구사항 분석
- MySQL, MongoDB, Redis를 적재적소 배치
- Database per Service 패턴 실무 적용

### 6. 인프라 형상 관리 능력

- Terraform 모듈 구조 설계 (세분화 vs 통합)
- 실무 조언 반영하여 유지보수 용이한 구조 구축
- Remote State 관리 (S3 + DynamoDB Lock)
- 개인 프로젝트 vs 현업 구분 명확화

### 7. 비용 최적화 능력

- 제한된 예산으로 개발계 수준 인프라 구축
- Lambda 하이브리드로 21% 비용 절감
- Single-AZ vs Multi-AZ 트레이드오프 분석
- 실제 사용량 측정 및 비용 분석

---

## 프로젝트 구조

```
erp-project/
├── backend/                          # 4개 마이크로서비스
│   ├── employee-service/             # 직원 관리 (MySQL) → Lambda
│   ├── approval-request-service/     # 결재 요청 (MongoDB) → EKS
│   ├── approval-processing-service/  # 결재 처리 (In-Memory) → EKS
│   └── notification-service/         # 알림 (Redis + WebSocket) → EKS
│
├── frontend/                         # React + Vite
│
├── infrastructure/terraform/dev/     # Terraform IaC (14개 모듈)
│   ├── erp-dev-VPC/                  # VPC, Subnet, NAT Gateway
│   ├── erp-dev-SecurityGroups/       # 세분화 (4개 tfstate)
│   ├── erp-dev-IAM/                  # 통합 (1개 tfstate, 4개 Role)
│   ├── erp-dev-Secrets/              # Secrets Manager
│   ├── erp-dev-Databases/            # RDS, ElastiCache
│   ├── erp-dev-EKS/                  # EKS Cluster, 2개 Node Group
│   ├── erp-dev-ECR/                  # 4개 Repository (1 Lambda + 3 EKS)
│   ├── erp-dev-LoadBalancerController/
│   ├── erp-dev-Lambda/               # Employee Service Lambda
│   ├── erp-dev-APIGateway/           # API Gateway, NLB
│   ├── erp-dev-Frontend/             # S3, CloudFront
│   ├── erp-dev-Cognito/              # User Pool, App Client
│   ├── erp-dev-ParameterStore/       # 6개 Parameter (buildspec.yml용)
│   └── erp-dev-CloudWatch/           # SNS + 3개 Alarm
│
├── helm-chart/                       # Kubernetes Helm Chart
│   ├── Chart.yaml
│   ├── values-dev.yaml               # 개발 환경 설정
│   └── templates/                    # 12개 템플릿
│       ├── deployment.yaml           # 3개 EKS 서비스 통합
│       ├── service.yaml              # ClusterIP (모두)
│       ├── hpa.yaml                  # Auto Scaling
│       ├── externalsecret.yaml       # Secrets Manager 연동
│       ├── targetgroupbinding.yaml   # NLB 연결
│       ├── kafka.yaml                # Kafka + Zookeeper
│       ├── fluent-bit.yaml           # CloudWatch Logs 수집
│       └── xray-daemonset.yaml       # X-Ray 트레이싱
│
├── re_build/                         # 재구축 가이드 (9개 문서)
│   ├── 00_START_HERE.md              # 전체 개요
│   ├── 01_SECRETS_SETUP.md           # Secrets Manager 설정
│   ├── 02_TERRAFORM.md               # Terraform 배포 (2시간)
│   ├── 03_IMAGE_BUILD.md             # 이미지 빌드 & ECR 푸시
│   ├── 04_LAMBDA_DEPLOY.md           # Lambda 배포 (2시간)
│   ├── 05_HELM_CHART.md              # Helm Chart 배포
│   ├── 06_BUILDSPEC.md               # buildspec.yml 작성 (4시간)
│   ├── 07_CODEPIPELINE.md            # CodePipeline 생성
│   └── 08_VERIFICATION.md            # 검증 및 테스트
│
└── buildspec.yml                     # CodeBuild 빌드 스크립트
```

---

## 빠른 시작

### 로컬 실행
```bash
git clone https://github.com/sss654654/erp-microservices.git
cd erp-project
docker-compose up -d
```

### AWS 배포
```bash
cd infrastructure/terraform/dev
# VPC → SecurityGroups → IAM → Databases → EKS 순차 배포
```

**상세 가이드:**
- [re_build/00_START_HERE.md](./re_build/00_START_HERE.md) - 재구축 마스터 가이드
- [backend/README.md](./backend/README.md) - 서비스별 API 명세
- [infrastructure/README.md](./infrastructure/README.md) - Terraform 배포 가이드
- [helm-chart/README.md](./helm-chart/README.md) - Kubernetes 설정

---

## 회고

### 잘한 점

1. **Lambda 하이브리드 구조**: Employee Service를 Lambda로 전환하여 비용 21% 절감
2. **완전 자동화 CI/CD**: Git Push → 3분 11초 배포 (배포 시간 90% 단축)
3. **AWS Native 모니터링**: CloudWatch Logs + X-Ray + Alarm 통합
4. **문제를 직접 경험**: gRPC로 먼저 구현하여 동기 통신의 한계를 체감
5. **데이터 기반 의사결정**: 측정 데이터로 문제 정량화, 개선 효과 검증
6. **실무 조언 반영**: 멘토 조언을 바탕으로 Terraform 구조 설계
7. **트레이드오프 인식**: Single-AZ 선택 시 고가용성 포기를 명확히 인식

### 아쉬운 점

1. **모니터링 부족**: 
   - Prometheus + Grafana 미구현
   - Kafka Lag 모니터링 부재
   - 개선: Prometheus Operator + Grafana 대시보드 구축

2. **테스트 자동화**: 
   - 단위 테스트, 통합 테스트 부족
   - 개선: TDD 방식으로 테스트 커버리지 확보

3. **보안 강화 필요**: 
   - Kafka TLS/SSL 미적용
   - Network Policy 미설정
   - 개선: 초기 설계에 보안 요구사항 반영

4. **Kafka를 Deployment로 배포**: 
   - **문제**: Stateful 애플리케이션을 Deployment로 배포하여 데이터 영속성 없음
   - **영향**: Pod 재시작 시 모든 메시지 소실
   - **원인**: 개발 환경이므로 비용 절감 우선, Kafka 비동기 메시징 학습에 집중
   - **개선**: StatefulSet + PVC로 구현하면 데이터 보존 가능 (비용 $2.4/월)
   - **프로덕션**: MSK (Managed Streaming for Kafka) 사용 권장 ($310/월)
   - **상세**: [helm-chart/README.md](./helm-chart/README.md#kafka-구현)

5. **Terraform 전체 구현**: 
   - **문제**: 시간 부족으로 모든 리소스를 Terraform으로 구현
   - **현업**: VPC, Subnet, ECR, DB Subnet까지만 Terraform, 나머지는 콘솔 관리가 일반적
   - **배운 점**: 어떤 리소스를 Terraform으로 하고 어떤 것을 직접 만들어야 하는지 개념적으로만 알고 직접 느껴보지 못함
   - **개선**: 변경 빈도와 협업 필요성을 고려한 리소스별 관리 방식 체득

### 다음 프로젝트에서 개선할 점

1. **모니터링 구축**: Prometheus + Grafana로 Kafka Lag, Pod 메트릭 실시간 모니터링
2. **테스트 자동화**: TDD 방식으로 단위/통합 테스트 커버리지 확보
3. **보안 강화**: Kafka TLS/SSL, Network Policy를 초기 설계에 반영
4. **Kafka StatefulSet**: 데이터 영속성 확보 (StatefulSet + PVC)
5. **Terraform vs 콘솔 기준**: 변경 빈도와 협업 필요성을 고려한 리소스별 관리 방식 체득

---

**"완벽한 설계는 없다. 문제를 경험하고, 측정하고, 개선하는 과정이 중요하다."**

이 프로젝트는 **Lambda 하이브리드 구조**로 비용을 21% 절감하고, **완전 자동화 CI/CD**로 배포 시간을 90% 단축했으며, **AWS Native 모니터링**으로 실시간 장애 감지 체계를 구축한 과정을 담았습니다. CGV에서 Kinesis를 경험한 후, 마이크로서비스 환경에서는 Consumer Group과 Offset 관리가 유리한 Kafka를 선택하여 서비스 간 비동기 메시징을 구현했습니다. 동기 통신(gRPC)의 한계를 직접 겪고 비동기 아키텍처로 전환하여 응답 시간을 85% 개선했습니다 (850ms → 120ms).
