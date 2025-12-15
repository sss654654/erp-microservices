# ERP 마이크로서비스 전자결재 시스템

4개 독립 서비스 + 3가지 통신 프로토콜 + 이종 데이터베이스 통합

---

## 이 프로젝트가 해결하려는 문제

### CGV 프로젝트의 한계

이전 CGV 대기열 시스템에서 **Kinesis + Redis를 활용한 대량 트래픽 처리**에는 성공했습니다. 1차원적으로 "많은 요청을 빠르게 처리한다"는 목표는 달성했지만, 고차원적으로 생각했을 때 **단일 API 서버 구조**였습니다.

**CGV 프로젝트 구조:**
```
대량 트래픽 → ALB → 단일 API 서버 → Kinesis → Redis → RDS Aurora
```
- Kinesis로 요청 버퍼링
- Redis로 대기열 관리
- 대량 트래픽 처리 성공

**하지만 마이크로서비스가 아니었던 이유:**
- 모든 기능이 하나의 서버에 집중 (대기열, 예매, 결제 등)
- 서비스 간 통신 개념 부재
- 하나의 기능 장애 시 전체 시스템 영향
- 독립적인 확장 불가능

이 경험을 통해 **"대량 트래픽 처리"와 "마이크로서비스 아키텍처"는 다른 문제**임을 깨달았고, 실무에서 더 자주 마주치는 **마이크로서비스 환경의 문제**를 경험하고 싶어 이번 프로젝트를 시작했습니다.

**경험하지 못한 실무 상황:**
- 서비스 간 통신이 느려지면 전체 시스템이 느려지는 문제
- 한 서비스 장애가 다른 서비스로 전파되는 문제
- 서비스마다 다른 데이터 특성에 맞는 DB 선택
- 여러 서비스를 하나의 API로 통합 관리
- CI/CD 파이프라인 직접 설계 (CGV에서는 GitLab CI/CD 코드를 받아서 백엔드용으로 리팩토링만 함)

### 이 프로젝트에서 해결하려는 것

**"마이크로서비스에서 발생하는 실제 문제를 직접 겪고, 해결책을 찾는다"**

1. **동기 통신의 블로킹 문제**: gRPC로 구현 → 문제 발견 → Kafka로 전환
2. **서비스별 최적 DB 선택**: 데이터 특성 분석 → MySQL/MongoDB/Redis 적재적소 배치
3. **마이크로서비스 통합 관리**: 4개 서비스를 API Gateway로 단일 진입점 구성
4. **CI/CD 파이프라인 직접 설계**: DVA 학습 후 CodePipeline으로 GitHub → ECR → EKS 자동 배포 구축
5. **인프라 형상 관리**: Terraform으로 전체 인프라 코드화, 실무 구조 반영

---

## 아키텍처

### 전체 시스템 구조

```
┌─────────────────────────────────────────────────────────────┐
│                   CloudFront (Frontend)                      │
│              https://d95pjcr73gr6g.cloudfront.net            │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    S3 Bucket (React SPA)                     │
│                   - Static Website Hosting                   │
└─────────────────────────────────────────────────────────────┘
                     │ API 호출
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              API Gateway (HTTP API)                          │
│       https://mqi4qaw3bb.execute-api.ap-northeast-2...       │
│                   - Cognito Authorizer (JWT 검증)            │
│                   - CORS 중앙 관리                           │
│                   - VPC Link (Private 통신)                  │
└────────────────────┬────────────────────────────────────────┘
                     │ VPC Link
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Network Load Balancer (Layer 4)                 │
│                   - Cross-Zone Load Balancing                │
│                   - 4개 Target Group                         │
└────┬──────┬──────┬──────┬──────────────────────────────────┘
     │      │      │      │
┌────▼┐ ┌──▼──┐ ┌─▼──┐ ┌─▼──┐
│Empl-│ │Appr-│ │Appr-│ │Noti-│
│oyee │ │oval │ │oval │ │fica-│
│     │ │Req  │ │Proc │ │tion │
│8081 │ │8082 │ │8083 │ │8084 │
│2Pod │ │2Pod │ │2Pod │ │2Pod │
└──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘
   │       │       │       │
   │       └───┬───┘       │
   │           │           │
   │      ┌────▼────┐      │
   │      │  Kafka  │      │
   │      │ Cluster │      │
   │      │ (EKS)   │      │
   │      └─────────┘      │
   │                       │
┌──▼───────────────────────▼──┐
│     MySQL (RDS)             │
│  - employees                │
│  - leave_balance            │
│  - leave_request            │
│  - attendance               │
│  - quest                    │
└─────────────────────────────┘
```

### VPC 네트워크 설계

```
VPC: 10.0.0.0/16
├── Public Subnet 1:  10.0.0.0/24 (ap-northeast-2a) - NAT Gateway
├── Public Subnet 2:  10.0.1.0/24 (ap-northeast-2c)
├── Private Subnet 1: 10.0.10.0/24 (ap-northeast-2a) - EKS Nodes
├── Private Subnet 2: 10.0.11.0/24 (ap-northeast-2c) - EKS Nodes
├── Data Subnet 1:    10.0.20.0/24 (ap-northeast-2a) - RDS, Redis
└── Data Subnet 2:    10.0.21.0/24 (ap-northeast-2c) - RDS, Redis
```

**설계 원칙:**
- Multi-AZ: 2개 가용 영역 (고가용성)
- Public/Private 분리: 데이터베이스는 Private Subnet
- NAT Gateway: 1개만 배치 (비용 절감, Public Subnet 1에 위치)

### 기술 스택

| 계층 | 기술 | 버전 | 선택 이유 |
|------|------|------|-----------|
| **Backend** | Spring Boot | 3.3.5 | 엔터프라이즈급 안정성 |
| | Java | 17 | LTS 버전, 최신 기능 |
| **Database** | MySQL | 8.0 | ACID 트랜잭션 |
| | MongoDB | 7.0 | 문서형 DB, 유연한 스키마 |
| | Redis | 7.0 | 인메모리 캐시 |
| **Messaging** | Apache Kafka | 3.6.0 | 비동기 이벤트 처리 |
| **Frontend** | React | 18.2 | 컴포넌트 기반 |
| | Vite | 5.0 | 빠른 HMR |
| **Infrastructure** | Terraform | 1.6.0 | IaC |
| | Kubernetes (EKS) | 1.31 | 컨테이너 오케스트레이션 |
| | Docker | 24.0 | 컨테이너 런타임 |
| **CI/CD** | CodePipeline | - | GitHub 연동 |
| | CodeBuild | - | Docker 빌드 |
| **AWS** | API Gateway | - | 마이크로서비스 통합 |
| | NLB | - | Layer 4 로드밸런싱 |
| | CloudFront | - | CDN |
| | Cognito | - | 인증/인가 |

---

## 문제 해결 과정

### 1. 동기 통신의 한계 경험

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

**왜 이런 문제가 발생했는가?**
- Request Service가 Processing Service의 응답을 기다리는 동안 스레드 블로킹
- 네트워크 지연, 처리 시간이 누적되어 전체 응답 시간 증가
- 한 서비스의 장애가 호출하는 서비스로 전파

### 2. Kafka 비동기 메시징으로 전환

**3단계: 문제 해결**

```
Approval Request Service
  ↓ Kafka Produce (비동기, 즉시 반환)
Kafka Topic
  ↓ Consumer Group (병렬 처리)
Approval Processing Service
```

**개선 결과:**
- 평균 응답 시간: 120ms (약 85% 감소, 850ms → 120ms)
- 에러율: 0% (완전 제거)
- 처리량: 250 req/sec (약 610% 증가, 35 → 250 req/sec)
- **해결**: Processing Service 다운되어도 메시지는 Kafka에 보존, 복구 후 자동 처리

**배운 점:**
- 동기 통신은 간단하지만 확장성과 안정성에 한계
- 비동기 메시징은 복잡도가 높지만 장애 격리와 성능 개선 효과 큼
- 실무에서 마이크로서비스는 비동기 통신이 필수

**Kinesis vs Kafka 선택:**

CGV 프로젝트에서는 Kinesis를 사용했지만, 이번에는 Kafka를 선택했습니다.

| 항목 | Kinesis (CGV) | Kafka (ERP) |
|------|---------------|-------------|
| 사용 패턴 | 단일 서비스 내 대기열 처리 | 서비스 간 메시징 |
| 구조 | API 서버 → Kinesis → 동일 서버 처리 | Request Service → Kafka → Processing Service |
| Consumer | 단일 Consumer | Consumer Group (병렬) |
| 목적 | 대량 트래픽 버퍼링 | 서비스 간 비동기 통신 |

**핵심 차이:**
- CGV: Kinesis가 하나의 서비스 내에서 메시지를 저장하고 순차 처리하는 버퍼 역할
- ERP: Kafka가 독립된 서비스 간 메시지를 전달하는 메시징 역할 (마이크로서비스 특징 활용)

**Kafka 직접 설치 선택:**
- AWS MSK: 월 $300+ (관리형 서비스)
- Kafka on EKS: 추가 비용 없음 (기존 EKS 노드 활용)
- 제한된 예산($180)으로 Helm Chart 사용하여 EKS에 직접 배포

### 3. 데이터 특성에 맞는 DB 선택

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

### 4. 아키텍처 선택: Kubernetes Service 타입과 로드밸런서

**CGV vs ERP: 다른 목표, 다른 아키텍처**

**CGV 프로젝트 (대규모 트래픽 처리)**
```
ALB → Ingress → Service (ClusterIP) → Pod (단일 API)
```
- 목표: 10,000명 동시 접속을 단일 진입점에서 분배
- ALB로 충분 (Layer 7 라우팅, 가용성 중심)

**ERP 프로젝트 (마이크로서비스 관리)**
```
API Gateway → VPC Link → NLB (Terraform 생성)
  ├─ Target Group 1 → Employee Pods (ClusterIP + TargetGroupBinding)
  ├─ Target Group 2 → Approval Request Pods (ClusterIP + TargetGroupBinding)
  ├─ Target Group 3 → Approval Processing Pods (ClusterIP + TargetGroupBinding)
  └─ Target Group 4 → Notification Pods (ClusterIP + TargetGroupBinding)
```
- 목표: 4개 독립 서비스를 단일 API로 통합 관리
- **NLB 1개**에 모든 Service 연결 (비용 절감)
- TargetGroupBinding으로 Pod IP를 NLB Target Group에 직접 등록

**핵심 차이:**

| Service 타입 | CGV | ERP |
|-------------|-----|-----|
| ClusterIP | ✅ Ingress가 참조 | ✅ 모든 Service (TargetGroupBinding) |
| LoadBalancer | ❌ Ingress로 충분 | ❌ 불필요 (NLB는 Terraform 생성) |
| Ingress | ✅ ALB 생성 | ❌ API Gateway와 중복 |

**배운 점:**
- 아키텍처는 요구사항에 따라 자연스럽게 도출됨
- API Gateway 사용 시 VPC Link는 NLB만 지원 (ALB 불가)
- 모든 Service를 ClusterIP + TargetGroupBinding으로 통일하는 것이 표준 패턴

**현재 구조의 문제점:** [manifests/README.md - NLB 구조 문제](./manifests/README.md#nlb-구조의-문제점)

### 5. Terraform 구조 설계

**멘토 조언:**
> "실무에서는 보안그룹이나 RDS를 Terraform으로 관리하면 정책 1개만 달라져도 틀어져서 여러 부서가 함께하는 프로젝트에는 부적합. 폴더는 세분화하고 각 tfstate 파일을 따로 저장하는게, 콘솔 작업 후 형상 맞춰주기 좋음."

**하지만 개인 프로젝트 특성상:**
- 1인 개발이므로 협업 충돌 없음
- 학습 목적으로 전체 인프라를 Terraform으로 구축
- 현업 전환 시: VPC, Subnet, Route Table, ECR, DB Subnet까지만 Terraform, 나머지는 콘솔 관리

**고민: 세분화 vs 통합**

**SecurityGroups: 세분화 선택**
```
erp-dev-SecurityGroups/
├── eks-cluster-sg/     # tfstate 1
├── eks-node-sg/        # tfstate 2
├── rds-sg/             # tfstate 3
└── elasticache-sg/     # tfstate 4
```
- 이유: 각 SG는 독립적으로 수정 빈도가 다름
- 콘솔에서 급하게 수정 후 import 용이
- State Lock 충돌 없음

**IAM: 통합 선택**
```
erp-dev-IAM/
├── main.tf             # 각 role 폴더 module 호출
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

### 6. Redis Pub/Sub로 멀티 Pod 알림 문제 해결

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

### 7. CI/CD 파이프라인 직접 설계

**CGV 프로젝트의 한계:**
- GitLab CI/CD 코드를 받아서 백엔드용으로 리팩토링만 함
- 파이프라인 구조는 이해했지만 직접 설계 경험 부족
- AWS 네이티브 CI/CD 도구 미경험

**DVA 취득 후 학습:**
- CodePipeline, CodeBuild, CodeDeploy 개념 학습
- IAM Role 기반 권한 관리
- EKS 배포 자동화 방법

**이번 프로젝트에서 구현:**
```
GitHub Push
  ↓
CodePipeline (트리거)
  ↓
CodeBuild (빌드)
  - Maven package
  - Docker build
  - ECR push
  ↓
kubectl set image (배포)
  ↓
EKS Rolling Update
```

**buildspec.yml 직접 작성:**
- ECR 로그인
- Maven 빌드
- Docker 이미지 빌드 및 푸시
- kubectl로 EKS 배포

**배운 점:**
- CI/CD 파이프라인을 직접 설계하면서 각 단계의 역할 이해
- IAM Role 권한 설정의 중요성 (CodeBuild가 ECR, EKS 접근 권한 필요)
- 빌드 실패 시 디버깅 방법 (CloudWatch Logs 확인)

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

**Single-AZ 선택:**

| 항목 | 프로덕션 | 개발계 | 선택 |
|------|---------|--------|------|
| RDS | $30/월 | $15/월 | Single-AZ |
| NAT Gateway | $64/월 | $32/월 | Single-AZ |

**절감 효과**: 월 $47 절감

**트레이드오프 인식:**
- 고가용성 포기 (99.95% → 99.5%)
- 다운타임 허용 (자동 Failover 없음)
- 학습 목적이므로 기능 검증이 최우선
- 프로덕션 전환 시 Terraform 변수 하나로 Multi-AZ 전환 가능

---

## 얻은 능력

### 1. 문제 정의 및 해결 능력

- gRPC 동기 통신의 문제점을 측정 데이터로 정량화
- Kafka 비동기 메시징으로 전환하여 85% 성능 개선
- 문제 → 측정 → 분석 → 해결 → 검증 프로세스 경험

### 2. 데이터 특성 분석 및 DB 선택 능력

- 데이터 구조, 조회 패턴, 확장성 요구사항 분석
- MySQL, MongoDB, Redis를 적재적소 배치
- Database per Service 패턴 실무 적용

### 3. 아키텍처 설계 능력

- 단일 API vs 마이크로서비스 차이 이해
- ALB vs API Gateway 선택 기준 수립
- 동기 vs 비동기 통신 트레이드오프 이해

### 4. 인프라 형상 관리 능력

- Terraform 모듈 구조 설계 (세분화 vs 통합)
- 실무 조언 반영하여 유지보수 용이한 구조 구축
- 개인 프로젝트 vs 현업 구분 명확화

### 5. 비용 최적화 능력

- 제한된 예산으로 개발계 수준 인프라 구축
- Single-AZ vs Multi-AZ 트레이드오프 분석
- 실제 사용량 측정 및 비용 분석
- 12.6일부터 계속 가동하여 운영계와 가깝게 돌려보며 안정성 검증

### 6. CI/CD 파이프라인 설계 능력

- CodePipeline, CodeBuild로 GitHub → ECR → EKS 자동 배포 구축
- buildspec.yml 직접 작성하여 빌드/배포 단계 정의
- IAM Role 권한 설정 및 디버깅 경험

---

## 프로젝트 구조

### 전체 디렉토리 구조

```
erp-project/
├── backend/                          # 4개 마이크로서비스
│   ├── employee-service/             # 직원 관리 (MySQL)
│   ├── approval-request-service/     # 결재 요청 (MongoDB)
│   ├── approval-processing-service/  # 결재 처리 (In-Memory)
│   └── notification-service/         # 알림 (Redis + WebSocket)
│
├── frontend/                         # React + Vite
│
├── infrastructure/terraform/dev/     # Terraform IaC (9개 모듈)
│   ├── erp-dev-VPC/                  # VPC, Subnet, NAT Gateway
│   ├── erp-dev-SecurityGroups/       # 세분화 (4개 tfstate)
│   │   ├── eks-cluster-sg/
│   │   ├── eks-node-sg/
│   │   ├── rds-sg/
│   │   └── elasticache-sg/
│   ├── erp-dev-IAM/                  # 통합 (1개 tfstate)
│   │   ├── main.tf                   # module 호출
│   │   ├── eks-cluster-role/
│   │   ├── eks-node-role/
│   │   ├── codebuild-role/
│   │   └── codepipeline-role/
│   ├── erp-dev-Secrets/              # Secrets Manager
│   ├── erp-dev-Databases/            # RDS, ElastiCache
│   ├── erp-dev-EKS/                  # EKS Cluster, Node Group
│   ├── erp-dev-LoadBalancerController/
│   ├── erp-dev-APIGateway/           # API Gateway, NLB
│   ├── erp-dev-Frontend/             # S3, CloudFront
│   └── erp-dev-Cognito/              # User Pool, App Client
│
└── manifests/                        # Kubernetes Manifests
    ├── base/                         # ConfigMap, Secret, TargetGroupBinding
    ├── employee/                     # Deployment, Service, HPA
    ├── approval-request/             # Deployment, Service, HPA
    ├── approval-processing/          # Deployment, Service, HPA
    ├── notification/                 # Deployment, Service, HPA
    └── kafka/                        # Kafka Deployment
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
- [backend/README.md](./backend/README.md) - 서비스별 API 명세
- [infrastructure/README.md](./infrastructure/README.md) - Terraform 배포 가이드
- [manifests/README.md](./manifests/README.md) - Kubernetes 설정

---

## 회고

### 잘한 점

1. **문제를 직접 경험**: gRPC로 먼저 구현하여 동기 통신의 한계를 체감
2. **데이터 기반 의사결정**: 측정 데이터로 문제 정량화, 개선 효과 검증
3. **실무 조언 반영**: 멘토 조언을 바탕으로 Terraform 구조 설계
4. **트레이드오프 인식**: Single-AZ 선택 시 고가용성 포기를 명확히 인식

### 아쉬운 점

1. **모니터링 부족**: Prometheus + Grafana 미구현, Kafka Lag 모니터링 부재
2. **테스트 자동화**: 단위 테스트, 통합 테스트 부족
3. **보안 강화 필요**: Kafka TLS/SSL 미적용, Network Policy 미설정
4. **Terraform 전체 구현**: 시간 부족으로 모든 리소스를 Terraform으로 구현. 현업에서는 VPC, Subnet, ECR, DB Subnet까지만 Terraform 사용하고 나머지는 콘솔 관리가 일반적. 어떤 리소스를 Terraform으로 하고 어떤 것을 직접 만들어야 하는지 개념적으로만 알고 직접 느껴보지 못함
5. **Kafka를 Deployment로 배포**: Stateful 애플리케이션을 Deployment로 배포하여 데이터 영속성 없음. Pod 재시작 시 모든 메시지 소실. StatefulSet + PVC로 구현했다면 데이터 보존 가능. 개발 환경이므로 비용 절감 우선, Kafka 비동기 메시징 학습에 집중. **상세: [manifests/README.md](./manifests/README.md#kafka-구현의-아쉬운-점)**
6. **NLB 구조 일관성 부족**: Notification Service를 LoadBalancer로 설정하여 불필요한 NLB 생성. 모든 Service를 ClusterIP + TargetGroupBinding으로 통일했어야 함. 초기 설계 부족으로 일관성 없는 혼합 구조. **상세: [manifests/README.md](./manifests/README.md#현재-nlb-구조-문제점)**
7. **하이브리드 구조 미구현**: Employee Service를 Lambda로 전환하면 EKS 비용 21% 절감 가능 ($82.30 → $64.73). 14일 기간 제약과 Kafka 학습 우선순위로 미구현. **상세: [infrastructure/README.md](./infrastructure/README.md#하이브리드-구조-미구현)**

### 이번 프로젝트에서 개선할 점

1. **NLB 구조 통일**: 모든 Service를 ClusterIP + TargetGroupBinding으로 일관성 있게 구현
2. **하이브리드 구조 구현**: 간단한 API는 Lambda, 복잡한 API는 EKS로 분리하여 비용 최적화
3. **모니터링 구축**: Prometheus + Grafana로 Kafka Lag, Pod 메트릭 실시간 모니터링
4. **테스트 자동화**: TDD 방식으로 단위/통합 테스트 커버리지 확보
5. **보안 강화**: Kafka TLS/SSL, Network Policy를 초기 설계에 반영
6. **Terraform vs 콘솔 기준**: 변경 빈도와 협업 필요성을 고려한 리소스별 관리 방식 체득

---

**"완벽한 설계는 없다. 문제를 경험하고, 측정하고, 개선하는 과정이 중요하다."**

이 프로젝트는 CI/CD 파이프라인을 직접 설계하고, Terraform으로 전체 인프라를 코드화한 과정을 담았습니다. CGV에서 Kinesis를 경험한 후, 마이크로서비스 환경에서는 Consumer Group과 Offset 관리가 유리한 Kafka를 선택하여 서비스 간 비동기 메시징을 구현했습니다. 동기 통신(gRPC)의 한계를 직접 겪고 비동기 아키텍처로 전환하여 응답 시간을 약 85% 개선했습니다 (850ms → 120ms).
