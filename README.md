# ERP 마이크로서비스 프로젝트

**프로젝트**: ERP 전자결재 시스템  
**아키텍처**: 마이크로서비스 (4개 서비스)  
**배포 환경**: AWS EKS (Kubernetes)  
**최종 업데이트**: 2025-12-10

---

## 📋 프로젝트 개요

Spring Boot 기반 마이크로서비스 아키텍처로 구현한 ERP 전자결재 시스템입니다.

### 주요 기능
- ✅ 직원 관리 (CRUD)
- ✅ 결재 요청 및 승인/반려
- ✅ 실시간 알림 (WebSocket)
- ✅ 순차 결재 플로우
- ✅ 에러 처리 및 검증

---

## 🏗️ 아키텍처

### 마이크로서비스 구성

```
┌─────────────────────────────────────────────────────────────┐
│                      API Gateway (HTTP)                      │
│          https://mqi4qaw3bb.execute-api...                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    Network Load Balancer                     │
│                  (Cross-Zone Enabled)                        │
└────────┬──────────┬──────────┬──────────┬───────────────────┘
         │          │          │          │
    ┌────▼───┐ ┌───▼────┐ ┌───▼────┐ ┌───▼────┐
    │Employee│ │Approval│ │Approval│ │Notifi- │
    │Service │ │Request │ │Process │ │cation  │
    │:8081   │ │:8082   │ │:8083   │ │:8084   │
    │2 Pods  │ │2 Pods  │ │2 Pods  │ │2 Pods  │
    └────┬───┘ └───┬────┘ └───┬────┘ └───┬────┘
         │         │          │ gRPC     │
         │         │          │ :9090    │
         │         └──────────┴──────────┘
    ┌────▼────────────────────▼───────────────────────────────┐
    │                 Amazon EKS Cluster (v1.31)               │
    │                  - Worker Nodes: t3.small × 2~3          │
    │                  - AZ: ap-northeast-2a, 2c               │
    └──────────────────────────────────────────────────────────┘
```

### 4개 마이크로서비스

| 서비스 | 포트 | 데이터베이스 | 역할 |
|--------|------|--------------|------|
| **Employee Service** | 8081 | MySQL (RDS) | 직원 정보 관리 |
| **Approval Request Service** | 8082, 9091 | MongoDB Atlas | 결재 요청 관리 |
| **Approval Processing Service** | 8083, 9090 | Redis (ElastiCache) | 결재 처리 |
| **Notification Service** | 8084 | Redis (ElastiCache) | 실시간 알림 |

---

## 🛠️ 기술 스택

### 백엔드
- **Framework**: Spring Boot 3.3.5
- **Language**: Java 17
- **Build Tool**: Maven
- **Communication**: REST API, gRPC, WebSocket

### 데이터베이스
- **MySQL**: RDS (직원 정보)
- **MongoDB**: Atlas (결재 요청)
- **Redis**: ElastiCache (캐시, 알림)

### 인프라
- **Container**: Docker
- **Orchestration**: Kubernetes (EKS 1.31)
- **IaC**: Terraform
- **CI/CD**: AWS CodePipeline + CodeBuild
- **Load Balancer**: Network Load Balancer
- **API Gateway**: AWS API Gateway (HTTP)

### 프론트엔드
- **Framework**: React 18
- **Build Tool**: Vite
- **Hosting**: S3 + CloudFront

---

## 📁 프로젝트 구조

```
erp-project/
├── backend/                          # 백엔드 서비스
│   ├── employee-service/             # 직원 관리
│   ├── approval-request-service/     # 결재 요청
│   ├── approval-processing-service/  # 결재 처리
│   ├── notification-service/         # 알림
│   └── proto/                        # gRPC Proto 파일
├── frontend/                         # React 프론트엔드
│   ├── src/
│   │   ├── components/               # UI 컴포넌트
│   │   ├── services/                 # API 서비스
│   │   └── config/                   # 설정
│   └── package.json
├── infrastructure/                   # Terraform 코드
│   └── terraform/dev/
│       ├── erp-dev-VPC/              # VPC 구성
│       ├── erp-dev-EKS/              # EKS 클러스터
│       ├── erp-dev-Databases/        # RDS, ElastiCache
│       ├── erp-dev-APIGateway/       # API Gateway
│       └── erp-dev-Frontend/         # S3, CloudFront
└── manifests/                        # Kubernetes Manifest
    ├── employee/                     # Employee Service
    ├── approval-request/             # Approval Request Service
    ├── approval-processing/          # Approval Processing Service
    └── notification/                 # Notification Service
```

---

## 🚀 빠른 시작

### 사전 요구사항

- AWS CLI 2.x
- kubectl 1.31+
- Terraform 1.6+
- Docker
- Maven 3.8+
- Node.js 18+

### 1. 저장소 클론

```bash
git clone https://github.com/sss654654/erp-microservices.git
cd erp-microservices
```

### 2. 인프라 구축

```bash
cd infrastructure/terraform/dev

# 각 모듈 순서대로 실행
cd erp-dev-VPC && terraform init && terraform apply -auto-approve
cd ../erp-dev-SecurityGroups && terraform init && terraform apply -auto-approve
cd ../erp-dev-IAM && terraform init && terraform apply -auto-approve
cd ../erp-dev-Databases && terraform init && terraform apply -auto-approve
cd ../erp-dev-EKS && terraform init && terraform apply -auto-approve
cd ../erp-dev-LoadBalancerController && terraform init && terraform apply -auto-approve
cd ../erp-dev-APIGateway && terraform init && terraform apply -auto-approve
cd ../erp-dev-Frontend && terraform init && terraform apply -auto-approve
```

### 3. Kubernetes 배포

```bash
# EKS 클러스터 연결
aws eks update-kubeconfig --name erp-dev --region ap-northeast-2

# 서비스 배포
kubectl apply -f manifests/base/
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

# S3 업로드
aws s3 sync dist/ s3://erp-dev-frontend-dev --delete

# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E3HPT0O3YKLR5N \
  --paths "/*"
```

---

## 🧪 테스트

### API 테스트 (Postman)

```bash
# Postman Collection Import
backend/ERP_Postman_Collection.json
```

### 직원 생성

```bash
curl -X POST https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev/api/employees \
  -H "Content-Type: application/json" \
  -d '{
    "name": "김철수",
    "department": "개발팀",
    "position": "시니어 개발자"
  }'
```

### 결재 요청

```bash
curl -X POST https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev/api/approvals \
  -H "Content-Type: application/json" \
  -d '{
    "requesterId": 4,
    "title": "연차 신청",
    "content": "12월 15일 연차 사용 신청합니다.",
    "steps": [
      {"step": 1, "approverId": 5},
      {"step": 2, "approverId": 6}
    ]
  }'
```

---

## 📊 모니터링

### Pod 상태 확인

```bash
kubectl get pods -n erp-dev -o wide
```

### 로그 확인

```bash
kubectl logs -n erp-dev -l app=employee-service --tail=50
kubectl logs -n erp-dev -l app=approval-request-service --tail=50
```

### 서비스 상태

```bash
kubectl get svc -n erp-dev
kubectl get hpa -n erp-dev
```

---

## 🔗 주요 URL

- **Frontend (HTTPS)**: https://d95pjcr73gr6g.cloudfront.net
- **Frontend (HTTP)**: http://erp-dev-frontend-dev.s3-website.ap-northeast-2.amazonaws.com
- **API Gateway**: https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev/api
- **WebSocket**: ws://a1f6404ce73204456ab80c9b7067c1b7-31ca2443dda9c9fd.elb.ap-northeast-2.amazonaws.com:8084/ws/notifications

---

## 📚 문서

- [백엔드 README](./backend/README.md)
- [프론트엔드 README](./frontend/README.md)
- [인프라 README](./infrastructure/README.md)
- [Kubernetes README](./manifests/README.md)
- [로컬 개발 가이드](./backend/LOCAL_SETUP.md)

---

## 🐛 트러블슈팅

### Pod가 CrashLoopBackOff 상태

```bash
# 로그 확인
kubectl logs -n erp-dev <pod-name>

# 환경 변수 확인
kubectl describe pod -n erp-dev <pod-name>
```

### API Gateway 503 에러

```bash
# NLB Target Group 확인
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region ap-northeast-2
```

### WebSocket 연결 실패

- HTTP 페이지에서 접속: http://erp-dev-frontend-dev.s3-website.ap-northeast-2.amazonaws.com
- HTTPS 페이지에서는 ws:// 연결 불가 (브라우저 보안 정책)

---

## 💰 비용

**월 예상 비용**: $191/월

- EKS Control Plane: $73
- Worker Nodes (t3.small × 2): $30
- RDS (db.t3.micro): $15
- ElastiCache (cache.t3.micro): $12
- NAT Gateway: $32
- NLB: $16
- 기타: $13

---

## 👥 기여자

- **홍수빈** - 전체 아키텍처 설계 및 구현

---

## 📄 라이선스

This project is licensed under the MIT License.

---

## 📞 문의

- GitHub: https://github.com/sss654654/erp-microservices
- Email: sss654654@gmail.com
