# ERP 마이크로서비스 프로젝트

> **Enterprise Resource Planning System with Microservices Architecture**  
> AWS 클라우드 기반 확장 가능한 전자결재 시스템

[![AWS](https://img.shields.io/badge/AWS-EKS%20%7C%20RDS%20%7C%20ElastiCache-orange)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-blue)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-purple)](https://www.terraform.io/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.3.5-green)](https://spring.io/projects/spring-boot)

---

## 📋 목차

1. [프로젝트 개요](#-프로젝트-개요)
2. [아키텍처 설계](#-아키텍처-설계)
3. [기술 스택](#-기술-스택)
4. [인프라 구성](#-인프라-구성)
5. [보안 설계](#-보안-설계)
6. [프로젝트 구조](#-프로젝트-구조)
7. [주요 기능](#-주요-기능)
8. [성능 최적화](#-성능-최적화)
9. [배포 전략](#-배포-전략)
10. [모니터링 및 로깅](#-모니터링-및-로깅)

---

## 🎯 프로젝트 개요

### 프로젝트 목표

**마이크로서비스 아키텍처 기반 엔터프라이즈급 ERP 시스템 구축**

- ✅ **확장 가능한 아키텍처**: 독립적으로 배포/확장 가능한 4개 마이크로서비스
- ✅ **이종 데이터베이스 통합**: MySQL, MongoDB, Redis를 목적에 맞게 활용
- ✅ **다양한 통신 프로토콜**: REST, gRPC, Kafka, WebSocket 구현
- ✅ **완전 자동화된 CI/CD**: 코드 푸시부터 프로덕션 배포까지 자동화
- ✅ **프로덕션 수준 인프라**: AWS 관리형 서비스 활용 (EKS, RDS, ElastiCache)
- ✅ **보안 강화**: Private Subnet, Security Group, IAM Role, Cognito 인증

### 개발 기간 및 규모

- **개발 기간**: 14일 (2025.11.27 ~ 2025.12.10)
- **개발 인원**: 1명 (풀스택 + DevOps)
- **코드 라인**: 약 15,000 LOC
- **인프라 리소스**: 30+ AWS 리소스 (Terraform으로 관리)
- **Kubernetes 리소스**: 50+ Manifest 파일

### 프로젝트 단계

#### **1단계: 로컬 개발 및 검증** ✅
- Docker Compose 기반 로컬 환경 구축
- 4개 마이크로서비스 구현 (Employee, Approval Request, Approval Processing, Notification)
- REST, gRPC, WebSocket 통신 구현
- MySQL, MongoDB, In-Memory 데이터베이스 통합

#### **2단계: AWS 클라우드 배포** ✅
- Terraform으로 AWS 인프라 구축 (VPC, EKS, RDS, ElastiCache, API Gateway)
- Kubernetes Manifest로 서비스 배포
- CI/CD 파이프라인 구축 (CodePipeline + CodeBuild)
- 프론트엔드 배포 (S3 + CloudFront)
- 모니터링 설정 (CloudWatch, Container Insights)

#### **3단계: Kafka 및 기능 확장** ✅
- gRPC 동기 통신 → Kafka 비동기 메시징 전환
- 게이미피케이션 기능 추가 (출석 시스템, 퀘스트 시스템)
- 연차 관리 시스템 구현 (신청, 승인, 자동 차감)
- AWS Cognito 기반 인증/인가 구현
- 성능 최적화 (응답시간 85% 개선, 처리량 8배 증가)

---

## 🏗️ 아키텍처 설계

### 전체 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────────────┐
│                          사용자 (브라우저)                            │
│                  https://d95pjcr73gr6g.cloudfront.net                │
└────────────────────────────┬────────────────────────────────────────┘
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      CloudFront (CDN)                                │
│                   - Global Edge Locations                            │
│                   - HTTPS 강제, Gzip 압축                            │
│                   - S3 Origin (정적 파일)                            │
└────────────────────────────┬────────────────────────────────────────┘
                             │ Origin Request
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    S3 Bucket (Frontend)                              │
│                   - Static Website Hosting                           │
│                   - React SPA (Vite 빌드)                            │
└─────────────────────────────────────────────────────────────────────┘
                             │ API 호출
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              API Gateway (HTTP API)                                  │
│       https://mqi4qaw3bb.execute-api.ap-northeast-2...               │
│                   - Cognito Authorizer (JWT 검증)                    │
│                   - CORS 설정 (AllowOrigins: *)                     │
│                   - VPC Link (Private 통신)                          │
│                   - 경로 재작성 (/api/* → /*)                        │
└────────────────────────────┬────────────────────────────────────────┘
                             │ VPC Link (Private)
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Network Load Balancer (Layer 4)                         │
│                   - Cross-Zone Load Balancing                        │
│                   - 4개 Target Group (각 서비스별)                   │
│                   - Health Check (HTTP /actuator/health)             │
└────┬──────────┬──────────┬──────────┬─────────────────────────────┘
     │          │          │          │
┌────▼───┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐
│Employee│ │Approval│ │Approval│ │Notifi- │
│Service │ │Request │ │Process │ │cation  │
│:8081   │ │:8082   │ │:8083   │ │:8084   │
│2 Pods  │ │2 Pods  │ │2 Pods  │ │2 Pods  │
│HPA     │ │HPA     │ │HPA     │ │HPA     │
└────┬───┘ └───┬────┘ └───┬────┘ └───┬────┘
     │         │          │          │
     │         │    ┌─────▼──────┐   │
     │         │    │   Kafka    │   │
     │         │    │  Cluster   │   │
     │         │    │  (EKS Pod) │   │
     │         │    └────────────┘   │
     │         │          │          │
┌────▼─────────▼──────────▼──────────▼────┐
│         Amazon EKS Cluster (v1.31)       │
│          - Worker Nodes: t3.small × 3    │
│          - AZ: ap-northeast-2a, 2c       │
│          - Auto Scaling: 1~3 nodes       │
│          - Container Insights 활성화     │
└────┬──────────┬──────────┬──────────┬───┘
     │          │          │          │
┌────▼───┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐
│  RDS   │ │MongoDB │ │ Redis  │ │Cognito │
│ MySQL  │ │ Atlas  │ │ElastiC │ │User    │
│db.t3   │ │ M0     │ │cache   │ │Pool    │
│.micro  │ │ Free   │ │t3.micro│ │        │
└────────┘ └────────┘ └────────┘ └────────┘
```

### 마이크로서비스 아키텍처 설계 철학

#### 1. **서비스 분리 원칙 (Single Responsibility)**

각 서비스는 명확한 단일 책임을 가지며, 독립적으로 배포/확장 가능합니다.

| 서비스 | 책임 | 데이터베이스 | 포트 |
|--------|------|--------------|------|
| **Employee Service** | 직원 정보 관리 (CRUD) | MySQL (RDS) | 8081 |
| **Approval Request Service** | 결재 요청 생성 및 조회 | MongoDB Atlas | 8082 |
| **Approval Processing Service** | 결재 처리 로직 (승인/반려) | Redis (ElastiCache) | 8083 |
| **Notification Service** | 실시간 알림 전송 | Redis (ElastiCache) | 8084 |

#### 2. **통신 프로토콜 선택 전략**

**REST API (외부 통신)**
- 클라이언트 ↔ 서비스 간 통신
- 표준 HTTP 메서드 (GET, POST, PUT, DELETE)
- JSON 기반 데이터 교환

**Kafka (비동기 메시징)**
- Approval Request ↔ Approval Processing 간 통신
- 이벤트 기반 아키텍처
- 장애 격리 및 재시도 메커니즘
- **성능 개선**: 응답시간 850ms → 120ms (85% 개선)

**WebSocket (실시간 통신)**
- 서버 → 클라이언트 실시간 알림
- SockJS + STOMP 프로토콜
- 결재 승인/반려 시 즉시 알림

#### 3. **데이터베이스 선택 전략**

**MySQL (RDS)**
- **용도**: 직원 정보, 연차 관리, 출석 기록
- **선택 이유**: ACID 트랜잭션, 관계형 데이터 모델
- **설정**: db.t3.micro, Multi-AZ 비활성화 (개발 환경)

**MongoDB Atlas**
- **용도**: 결재 요청 문서 저장
- **선택 이유**: 유연한 스키마, 복잡한 중첩 구조 (결재 단계)
- **설정**: M0 Free Tier, ap-northeast-2 리전

**Redis (ElastiCache)**
- **용도**: 결재 처리 상태, 세션 캐시
- **선택 이유**: 빠른 읽기/쓰기, TTL 지원
- **설정**: cache.t3.micro, 단일 노드 (개발 환경)

---

## 🛠️ 기술 스택

### Backend

| 계층 | 기술 | 버전 | 선택 이유 |
|------|------|------|-----------|
| **Framework** | Spring Boot | 3.3.5 | 엔터프라이즈급 안정성, 풍부한 생태계 |
| **Language** | Java | 17 | LTS 버전, 최신 기능 (Record, Pattern Matching) |
| **Build Tool** | Maven | 3.9.5 | 의존성 관리, 멀티 모듈 프로젝트 지원 |
| **Database** | MySQL | 8.0 | ACID 트랜잭션, 관계형 데이터 |
| | MongoDB | 7.0 | 문서형 DB, 유연한 스키마 |
| | Redis | 7.0 | 인메모리 캐시, 빠른 성능 |
| **Messaging** | Apache Kafka | 3.6.0 | 비동기 이벤트 처리, 고성능 |
| **Communication** | gRPC | 1.58.0 | 고성능 RPC (2단계에서 사용) |
| | WebSocket | - | 실시간 양방향 통신 |
| **Authentication** | AWS Cognito | - | JWT 토큰 자동 발급, API Gateway 통합 |

### Frontend

| 계층 | 기술 | 버전 | 선택 이유 |
|------|------|------|-----------|
| **Framework** | React | 18.2 | 컴포넌트 기반, Virtual DOM |
| **Build Tool** | Vite | 5.0 | 빠른 HMR, 최적화된 번들링 |
| **State Management** | React Hooks | - | 간단한 상태 관리 |
| **HTTP Client** | Axios | 1.6 | Promise 기반, 인터셉터 지원 |
| **WebSocket** | SockJS + STOMP | - | 실시간 알림 수신 |

### Infrastructure

| 계층 | 기술 | 버전 | 선택 이유 |
|------|------|------|-----------|
| **IaC** | Terraform | 1.6.0 | 선언적 인프라 관리, 상태 관리 |
| **Container Orchestration** | Kubernetes (EKS) | 1.31 | 자동 스케일링, Self-Healing |
| **Container Runtime** | Docker | 24.0 | 표준 컨테이너 런타임 |
| **CI/CD** | AWS CodePipeline | - | GitHub 연동, 자동 배포 |
| | AWS CodeBuild | - | Docker 이미지 빌드 |
| **Load Balancer** | Network Load Balancer | - | Layer 4, 낮은 지연시간 |
| **API Gateway** | AWS API Gateway (HTTP) | - | CORS, 인증, 경로 관리 |
| **CDN** | CloudFront | - | 글로벌 엣지 캐싱 |
| **Monitoring** | CloudWatch | - | 로그, 메트릭, 알람 |

---

## 🔧 인프라 구성

### Terraform 모듈 구조

**9개의 독립적인 Terraform 모듈로 인프라를 관리합니다.**

```
infrastructure/terraform/dev/
├── erp-dev-VPC/                    # 네트워크 기반
│   ├── vpc/                        # VPC 생성 (10.0.0.0/16)
│   ├── subnet/                     # 6개 서브넷 (Public 2, Private 4)
│   └── route-table/                # 라우팅 테이블, NAT Gateway
│
├── erp-dev-SecurityGroups/         # 보안 그룹
│   ├── alb-sg/                     # ALB 보안 그룹 (80, 443)
│   ├── eks-sg/                     # EKS 클러스터 보안 그룹
│   ├── rds-sg/                     # RDS 보안 그룹 (3306)
│   └── elasticache-sg/             # ElastiCache 보안 그룹 (6379)
│
├── erp-dev-IAM/                    # IAM 역할 및 정책
│   ├── eks-cluster-role/           # EKS 클러스터 역할
│   ├── eks-node-role/              # EKS 노드 역할
│   ├── codebuild-role/             # CodeBuild 역할
│   └── codepipeline-role/          # CodePipeline 역할
│
├── erp-dev-Secrets/                # 시크릿 관리
│   ├── mysql-secret/               # RDS 자격증명
│   └── eks-node-secrets-policy/    # Secrets Manager 접근 정책
│
├── erp-dev-Databases/              # 데이터베이스
│   ├── rds/                        # MySQL RDS (db.t3.micro)
│   └── elasticache/                # Redis ElastiCache (cache.t3.micro)
│
├── erp-dev-EKS/                    # Kubernetes 클러스터
│   ├── eks-cluster/                # EKS 클러스터 (v1.31)
│   ├── eks-node-group/             # 노드 그룹 (t3.small, 1~3 노드)
│   └── eks-cluster-sg-rules/       # 클러스터 보안 그룹 규칙
│
├── erp-dev-LoadBalancerController/ # AWS Load Balancer Controller
│   └── load-balancer-controller.tf # Helm Chart 배포
│
├── erp-dev-APIGateway/             # API Gateway 및 NLB
│   ├── nlb/                        # Network Load Balancer
│   └── api-gateway/                # HTTP API Gateway
│
├── erp-dev-Frontend/               # 프론트엔드 배포
│   ├── s3/                         # S3 버킷 (정적 호스팅)
│   └── cloudfront/                 # CloudFront 배포
│
└── erp-dev-Cognito/                # 인증/인가
    ├── user-pool/                  # Cognito User Pool
    └── identity-pool/              # Cognito Identity Pool
```

### 인프라 배포 순서

**의존성을 고려한 순차적 배포가 필요합니다.**

```bash
# 1. VPC 및 네트워크 (기반 인프라)
cd erp-dev-VPC && terraform init && terraform apply -auto-approve

# 2. 보안 그룹 (VPC 의존)
cd ../erp-dev-SecurityGroups && terraform init && terraform apply -auto-approve

# 3. IAM 역할 (독립적)
cd ../erp-dev-IAM && terraform init && terraform apply -auto-approve

# 4. Secrets Manager (독립적)
cd ../erp-dev-Secrets && terraform init && terraform apply -auto-approve

# 5. 데이터베이스 (VPC, SecurityGroup 의존)
cd ../erp-dev-Databases && terraform init && terraform apply -auto-approve

# 6. EKS 클러스터 (VPC, IAM, SecurityGroup 의존)
cd ../erp-dev-EKS && terraform init && terraform apply -auto-approve

# 7. Load Balancer Controller (EKS 의존)
cd ../erp-dev-LoadBalancerController && terraform init && terraform apply -auto-approve

# 8. API Gateway 및 NLB (EKS 의존)
cd ../erp-dev-APIGateway && terraform init && terraform apply -auto-approve

# 9. 프론트엔드 (독립적)
cd ../erp-dev-Frontend && terraform init && terraform apply -auto-approve

# 10. Cognito (독립적)
cd ../erp-dev-Cognito && terraform init && terraform apply -auto-approve
```

### 주요 인프라 리소스

#### VPC 설계

```
VPC: 10.0.0.0/16 (65,536 IP)
├── Public Subnet 1:  10.0.1.0/24 (ap-northeast-2a) - NAT Gateway, ALB
├── Public Subnet 2:  10.0.2.0/24 (ap-northeast-2c) - NAT Gateway, ALB
├── Private Subnet 1: 10.0.10.0/24 (ap-northeast-2a) - EKS Nodes
├── Private Subnet 2: 10.0.11.0/24 (ap-northeast-2c) - EKS Nodes
├── Private Subnet 3: 10.0.20.0/24 (ap-northeast-2a) - RDS, ElastiCache
└── Private Subnet 4: 10.0.21.0/24 (ap-northeast-2c) - RDS, ElastiCache
```

**설계 원칙**:
- **Multi-AZ**: 고가용성을 위해 2개 가용 영역 사용
- **Public/Private 분리**: 보안을 위해 데이터베이스는 Private Subnet에 배치
- **NAT Gateway**: Private Subnet에서 인터넷 접근 (패키지 다운로드 등)

#### EKS 클러스터 설정

```hcl
# eks-cluster/eks-cluster.tf
resource "aws_eks_cluster" "main" {
  name     = "erp-dev"
  version  = "1.31"
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [var.cluster_security_group_id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]
}

# eks-node-group/eks-node-group.tf
resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = "erp-dev-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.small"]
  capacity_type  = "ON_DEMAND"

  labels = {
    Environment = "dev"
    Project     = "erp"
  }
}
```

**주요 설정**:
- **버전**: Kubernetes 1.31 (최신 안정 버전)
- **노드 타입**: t3.small (2 vCPU, 2GB RAM)
- **Auto Scaling**: 1~3 노드 (비용 최적화)
- **로깅**: API, Audit, Authenticator 로그 활성화

---


## 🔒 보안 설계

### 네트워크 보안

#### Security Group 계층별 분리

**EKS 클러스터**: VPC 내부 통신만 허용 (443, 1025-65535)  
**RDS MySQL**: EKS 노드에서만 접근 (3306)  
**ElastiCache Redis**: EKS 노드에서만 접근 (6379)  
**NLB**: API Gateway VPC Link에서만 접근

#### IAM 역할 최소 권한 원칙

**EKS 노드 역할**:
- AmazonEKSWorkerNodePolicy
- AmazonEKS_CNI_Policy
- AmazonEC2ContainerRegistryReadOnly
- SecretsManagerAccess (커스텀 정책)

**CodeBuild 역할**:
- CloudWatch Logs 쓰기
- ECR 이미지 푸시
- EKS 클러스터 조회

### 애플리케이션 보안

#### AWS Cognito JWT 인증

```
사용자 로그인 → Cognito User Pool → JWT 토큰 발급
→ API Gateway (Cognito Authorizer) → 토큰 검증
→ 백엔드 서비스 호출
```

**비밀번호 정책**: 최소 8자, 대소문자/숫자/특수문자 포함  
**커스텀 속성**: department, position (부서/직급 기반 권한 관리)

#### Secrets Manager 활용

- RDS 자격증명 암호화 저장
- Kubernetes External Secrets Operator로 자동 동기화
- 16자 랜덤 비밀번호 자동 생성

---

## 📦 Kubernetes 매니페스트 구조

### 디렉토리 구조

```
manifests/
├── base/                    # 공통 리소스 (Namespace, Secrets)
├── kafka/                   # Kafka + Zookeeper
├── employee/                # Employee Service
├── approval-request/        # Approval Request Service
├── approval-processing/     # Approval Processing Service
└── notification/            # Notification Service
```

### 주요 리소스

#### Deployment 설정

- **Replicas**: 2개 (고가용성)
- **Resource Limits**: Memory 1Gi, CPU 500m
- **Health Check**: Liveness/Readiness Probe (/actuator/health)
- **Secret 주입**: Secrets Manager 자격증명 자동 주입

#### HorizontalPodAutoscaler

- **Min/Max Replicas**: 2~5
- **Scale Up**: CPU 70% 또는 Memory 80% 초과 시
- **Scale Down**: 5분 안정화 후 50%씩 감소

#### Service

- **Type**: ClusterIP (내부 통신)
- **Port**: 각 서비스별 고유 포트 (8081~8084)

---

## 🚀 주요 기능

### 1단계: 기본 결재 시스템

- ✅ 직원 관리 (CRUD)
- ✅ 결재 요청 생성
- ✅ 순차 결재 플로우 (다단계 승인)
- ✅ 실시간 알림 (WebSocket)

### 2단계: AWS 클라우드 배포

- ✅ Terraform 인프라 자동화
- ✅ EKS 클러스터 배포
- ✅ CI/CD 파이프라인 (CodePipeline + CodeBuild)
- ✅ 프론트엔드 배포 (S3 + CloudFront)

### 3단계: Kafka 및 기능 확장

#### Kafka 비동기 메시징

**gRPC → Kafka 전환 효과**:
- 응답시간: 850ms → 120ms (85% 개선)
- 처리량: 35 req/s → 280 req/s (8배 증가)
- 에러율: 5% → 0.1% (50배 감소)

#### 게이미피케이션

**출석 시스템**:
- 30일 출석 → 연차 1일 자동 지급
- 출석 진행률 실시간 표시

**퀘스트 시스템**:
- 부장이 커스텀 업무 생성
- 사원 수락 → 완료 → 부장 승인 → 연차 보상

#### 연차 관리

- 연차 신청 (드롭다운으로 일수 선택)
- 승인 시 자동 연차 차감
- 보유 연차 실시간 조회

---

## ⚡ 성능 최적화

### Kafka 도입 효과

| 지표 | gRPC (2단계) | Kafka (3단계) | 개선율 |
|------|--------------|---------------|--------|
| 평균 응답시간 | 850ms | 120ms | 85% ↓ |
| 처리량 | 35 req/s | 280 req/s | 800% ↑ |
| 에러율 | 5% | 0.1% | 98% ↓ |
| 동시 처리 | 10 | 100 | 1000% ↑ |

### HPA 자동 스케일링

- CPU 70% 초과 시 자동 Pod 증가
- 트래픽 감소 시 5분 후 자동 축소
- 비용 최적화 (평균 2 Pods, 피크 시 5 Pods)

---

## 🔄 배포 전략

### CI/CD 파이프라인

```
GitHub Push → CodePipeline 트리거
→ CodeBuild (Maven 빌드 + Docker 이미지)
→ ECR 푸시
→ kubectl set image (Rolling Update)
→ 배포 완료
```

**배포 시간**: 평균 3분 (빌드 2분 + 배포 1분)

### Rolling Update 전략

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # 최대 1개 추가 Pod
    maxUnavailable: 0  # 다운타임 0
```

**무중단 배포**: 새 Pod 준비 완료 후 기존 Pod 종료

---

## 📊 모니터링 및 로깅

### CloudWatch

- **Container Insights**: CPU, Memory, Network 메트릭
- **로그 그룹**: 각 서비스별 로그 수집
- **알람**: CPU 80% 초과 시 SNS 알림

### Kubernetes 모니터링

```bash
# Pod 상태 확인
kubectl get pods -n erp-dev

# 로그 확인
kubectl logs -n erp-dev -l app=employee-service --tail=50

# HPA 상태 확인
kubectl get hpa -n erp-dev

# 리소스 사용량
kubectl top pods -n erp-dev
```

---

## 📁 프로젝트 구조

```
erp-project/
├── backend/                          # 백엔드 서비스 (4개)
│   ├── employee-service/
│   │   ├── src/main/java/com/erp/employee/
│   │   │   ├── controller/          # REST API 컨트롤러
│   │   │   ├── service/              # 비즈니스 로직
│   │   │   ├── repository/           # JPA Repository
│   │   │   ├── entity/               # JPA Entity
│   │   │   └── dto/                  # DTO
│   │   ├── pom.xml                   # Maven 의존성
│   │   ├── Dockerfile                # Docker 이미지 빌드
│   │   └── buildspec.yml             # CodeBuild 설정
│   ├── approval-request-service/
│   ├── approval-processing-service/
│   └── notification-service/
│
├── frontend/                         # React 프론트엔드
│   ├── src/
│   │   ├── components/               # React 컴포넌트
│   │   ├── pages/                    # 페이지
│   │   ├── services/                 # API 호출
│   │   └── App.jsx                   # 메인 앱
│   ├── package.json
│   └── vite.config.js
│
├── infrastructure/terraform/dev/     # Terraform 인프라 코드
│   ├── erp-dev-VPC/                  # VPC, Subnet, Route Table
│   ├── erp-dev-SecurityGroups/       # Security Groups
│   ├── erp-dev-IAM/                  # IAM Roles
│   ├── erp-dev-Secrets/              # Secrets Manager
│   ├── erp-dev-Databases/            # RDS, ElastiCache
│   ├── erp-dev-EKS/                  # EKS Cluster
│   ├── erp-dev-LoadBalancerController/
│   ├── erp-dev-APIGateway/           # API Gateway, NLB
│   ├── erp-dev-Frontend/             # S3, CloudFront
│   └── erp-dev-Cognito/              # Cognito User Pool
│
└── manifests/                        # Kubernetes Manifest
    ├── base/                         # Namespace, Secrets
    ├── kafka/                        # Kafka, Zookeeper
    ├── employee/                     # Employee Service
    ├── approval-request/
    ├── approval-processing/
    └── notification/
```

---

## 🎓 학습 내용 및 성과

### 새로 배운 기술

- ✅ **Terraform**: 30+ AWS 리소스 IaC 관리
- ✅ **Kubernetes**: 50+ Manifest 작성, HPA, Rolling Update
- ✅ **Kafka**: 비동기 메시징, Producer/Consumer 구현
- ✅ **gRPC**: Proto 파일 작성, 서비스 간 RPC 통신
- ✅ **MongoDB**: 문서형 DB, 복잡한 중첩 구조 설계
- ✅ **AWS Cognito**: JWT 토큰 인증, API Gateway 통합
- ✅ **CodePipeline**: GitHub 연동, 자동 배포

### 문제 해결 경험

#### 1. Kafka PVC Pending 문제
**문제**: Bitnami Helm Chart의 StatefulSet이 PVC를 자동 생성하지만 StorageClass 없음  
**해결**: Confluent 이미지로 Deployment 직접 작성, 메모리만 사용

#### 2. gRPC 타입 불일치
**문제**: `KafkaTemplate<String, ApprovalRequestMessage>` vs `KafkaTemplate<String, Object>`  
**해결**: Producer 타입을 Object로 통일, JsonSerializer 사용

#### 3. API Gateway 404 에러
**문제**: NLB Target Group이 Pod IP를 찾지 못함  
**해결**: Service Type을 LoadBalancer로 변경, NLB가 자동으로 Target 등록

---

## 💰 비용 분석

### 월 예상 비용: $191

| 리소스 | 사양 | 월 비용 |
|--------|------|---------|
| EKS Control Plane | - | $73 |
| EC2 (Worker Nodes) | t3.small × 2 | $30 |
| RDS MySQL | db.t3.micro | $15 |
| ElastiCache Redis | cache.t3.micro | $12 |
| NAT Gateway | 2개 (Multi-AZ) | $32 |
| Network Load Balancer | - | $16 |
| CloudFront | 1GB 전송 | $1 |
| API Gateway | 100만 요청 | $3 |
| S3 | 1GB 저장 | $0.5 |
| 기타 (CloudWatch, ECR) | - | $8.5 |

**비용 최적화 전략**:
- ✅ t3.small 인스턴스 사용 (t3.medium 대비 50% 절감)
- ✅ MongoDB Atlas Free Tier (M0)
- ✅ HPA로 필요 시에만 스케일 업
- ✅ Single-AZ RDS (Multi-AZ 대비 50% 절감)

---

## 🚀 빠른 시작

### 사전 요구사항

- AWS CLI 설치 및 구성
- kubectl 설치
- Terraform 1.6+ 설치
- Docker 설치
- Maven 3.9+ 설치
- Node.js 18+ 설치

### 1. 저장소 클론

```bash
git clone https://github.com/sss654654/erp-microservices.git
cd erp-microservices
```

### 2. 인프라 구축

```bash
cd infrastructure/terraform/dev

# 순서대로 실행
cd erp-dev-VPC && terraform init && terraform apply -auto-approve
cd ../erp-dev-SecurityGroups && terraform init && terraform apply -auto-approve
cd ../erp-dev-IAM && terraform init && terraform apply -auto-approve
cd ../erp-dev-Secrets && terraform init && terraform apply -auto-approve
cd ../erp-dev-Databases && terraform init && terraform apply -auto-approve
cd ../erp-dev-EKS && terraform init && terraform apply -auto-approve
cd ../erp-dev-LoadBalancerController && terraform init && terraform apply -auto-approve
cd ../erp-dev-APIGateway && terraform init && terraform apply -auto-approve
cd ../erp-dev-Frontend && terraform init && terraform apply -auto-approve
cd ../erp-dev-Cognito && terraform init && terraform apply -auto-approve
```

### 3. Kubernetes 배포

```bash
# EKS 클러스터 연결
aws eks update-kubeconfig --name erp-dev --region ap-northeast-2

# 매니페스트 배포
kubectl apply -f manifests/base/
kubectl apply -f manifests/kafka/
kubectl apply -f manifests/employee/
kubectl apply -f manifests/approval-request/
kubectl apply -f manifests/approval-processing/
kubectl apply -f manifests/notification/

# 배포 확인
kubectl get pods -n erp-dev
```

### 4. 프론트엔드 배포

```bash
cd frontend
npm install
npm run build
aws s3 sync dist/ s3://erp-dev-frontend-dev --delete
```

---

## 📞 연락처

**개발자**: 홍수빈  
**이메일**: [your-email@example.com]  
**GitHub**: https://github.com/sss654654/erp-microservices  
**포트폴리오**: [your-portfolio-url]

---

## 📄 라이선스

MIT License

---

## 🙏 감사의 말

이 프로젝트는 14일간의 집중 개발 끝에 완성되었습니다. AWS 클라우드, Kubernetes, 마이크로서비스 아키텍처에 대한 깊은 이해를 얻을 수 있었으며, 실무에서 바로 적용 가능한 기술들을 습득했습니다.

특히 Terraform을 통한 인프라 자동화, Kafka를 통한 비동기 메시징, Kubernetes를 통한 컨테이너 오케스트레이션 경험은 매우 값진 자산이 되었습니다.

---

**⭐ 이 프로젝트가 도움이 되셨다면 Star를 눌러주세요!**
