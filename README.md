# ERP 마이크로서비스 프로젝트

**프로젝트**: ERP 전자결재 시스템  
**아키텍처**: 마이크로서비스 (4개 서비스)  
**배포 환경**: AWS EKS (Kubernetes 1.31)  
**최종 업데이트**: 2025-12-10

---

## 프로젝트 개요

Spring Boot 기반 마이크로서비스 아키텍처로 구현한 ERP 전자결재 시스템입니다.

**주요 기능**
- 직원 관리 (CRUD)
- 결재 요청 및 승인/반려
- 실시간 알림 (WebSocket)
- 순차 결재 플로우

---

## 아키텍처

```
API Gateway (HTTP) → NLB → EKS Cluster
                              ├─ Employee Service (MySQL)
                              ├─ Approval Request Service (MongoDB)
                              ├─ Approval Processing Service (Redis)
                              └─ Notification Service (Redis + WebSocket)
```

**4개 마이크로서비스**

| 서비스 | 포트 | 데이터베이스 | 역할 |
|--------|------|--------------|------|
| Employee Service | 8081 | MySQL (RDS) | 직원 정보 관리 |
| Approval Request Service | 8082, 9091 | MongoDB Atlas | 결재 요청 관리 |
| Approval Processing Service | 8083, 9090 | Redis | 결재 처리 |
| Notification Service | 8084 | Redis | 실시간 알림 |

**통신 방식**
- REST API: 외부 통신
- gRPC: Request ↔ Processing Service 간 통신
- WebSocket: 실시간 알림 (SockJS + STOMP)

---

## 기술 스택

**백엔드**: Spring Boot 3.3.5, Java 17, Maven  
**프론트엔드**: React 18, Vite  
**데이터베이스**: MySQL (RDS), MongoDB Atlas, Redis (ElastiCache)  
**인프라**: Terraform, Kubernetes (EKS), Docker  
**CI/CD**: AWS CodePipeline + CodeBuild  
**로드밸런서**: Network Load Balancer  
**API Gateway**: AWS API Gateway (HTTP)

---

## 프로젝트 구조

```
erp-project/
├── backend/                          # 4개 마이크로서비스
│   ├── employee-service/
│   ├── approval-request-service/
│   ├── approval-processing-service/
│   └── notification-service/
├── frontend/                         # React 프론트엔드
├── infrastructure/terraform/dev/     # Terraform 모듈 (9개)
└── manifests/                        # Kubernetes Manifest
```

---

## 빠른 시작

**사전 요구사항**: AWS CLI, kubectl, Terraform, Docker, Maven, Node.js

### 1. 저장소 클론

```bash
git clone https://github.com/sss654654/erp-microservices.git
cd erp-microservices
```

### 2. 인프라 구축 (Terraform)

```bash
cd infrastructure/terraform/dev
# 각 모듈 순서대로 실행 (VPC → SecurityGroups → IAM → Databases → EKS → ...)
```

### 3. Kubernetes 배포

```bash
aws eks update-kubeconfig --name erp-dev --region ap-northeast-2
kubectl apply -f manifests/base/
kubectl apply -f manifests/employee/
kubectl apply -f manifests/approval-request/
kubectl apply -f manifests/approval-processing/
kubectl apply -f manifests/notification/
```

### 4. 프론트엔드 배포

```bash
cd frontend
npm install && npm run build
aws s3 sync dist/ s3://erp-dev-frontend-dev --delete
```

---

## 주요 URL

- **Frontend (HTTPS)**: https://d95pjcr73gr6g.cloudfront.net
- **Frontend (HTTP)**: http://erp-dev-frontend-dev.s3-website.ap-northeast-2.amazonaws.com
- **API Gateway**: https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev/api
- **WebSocket**: ws://a1f6404ce73204456ab80c9b7067c1b7-31ca2443dda9c9fd.elb.ap-northeast-2.amazonaws.com:8084

---

## 테스트

**직원 생성**
```bash
curl -X POST https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev/api/employees \
  -H "Content-Type: application/json" \
  -d '{"name":"김철수","department":"개발팀","position":"시니어 개발자"}'
```

**결재 요청**
```bash
curl -X POST https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev/api/approvals \
  -H "Content-Type: application/json" \
  -d '{"requesterId":4,"title":"연차 신청","content":"12월 15일 연차","steps":[{"step":1,"approverId":5}]}'
```

---

## 모니터링

```bash
kubectl get pods -n erp-dev
kubectl logs -n erp-dev -l app=employee-service --tail=50
kubectl get hpa -n erp-dev
```

---

## 비용

**월 예상 비용**: $191

- EKS Control Plane: $73
- Worker Nodes (t3.small × 2): $30
- RDS (db.t3.micro): $15
- ElastiCache: $12
- NAT Gateway: $32
- NLB: $16
- 기타: $13

---

## 문서

- [백엔드 README](./backend/README.md)
- [프론트엔드 README](./frontend/README.md)
- [인프라 README](./infrastructure/README.md)
- [Kubernetes README](./manifests/README.md)

---

## 라이선스

MIT License
