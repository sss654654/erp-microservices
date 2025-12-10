# ERP 백엔드 서비스

**프레임워크**: Spring Boot 3.3.5  
**언어**: Java 17  
**빌드**: Maven  
**최종 업데이트**: 2025-12-10

---

## 서비스 구성

### 1. Employee Service (직원 관리)

**포트**: 8081  
**데이터베이스**: MySQL (RDS)  
**역할**: 직원 정보 CRUD 및 검증

**API**: GET/POST/PUT/DELETE `/employees`, `/employees/{id}`

### 2. Approval Request Service (결재 요청)

**포트**: 8082 (HTTP), 9091 (gRPC Server)  
**데이터베이스**: MongoDB Atlas  
**역할**: 결재 요청 생성 및 관리

**API**: GET/POST `/approvals`, `/approvals/{requestId}`  
**gRPC**: `ReturnApprovalResult()` - Processing Service로부터 결과 수신

**특징**
- MongoDB Sequence Generator로 requestId 생성 (중복 방지)
- gRPC Server로 결재 결과 수신
- Notification Service 호출 (최종 승인/반려 시)

### 3. Approval Processing Service (결재 처리)

**포트**: 8083 (HTTP), 9090 (gRPC Client)  
**데이터베이스**: Redis (ElastiCache)  
**역할**: 결재 대기 목록 관리 및 승인/반려 처리

**API**: GET `/process/{approverId}`, POST `/process/{approverId}/{requestId}`  
**gRPC**: `RequestApproval()`, `ReturnApprovalResult()` - Request Service 호출

**특징**
- Redis에 대기 목록 저장 (2개 Replica Pod 간 공유)
- gRPC Client로 Request Service와 통신
- 순차 결재 로직 (1단계 승인 후 2단계 전달)

### 4. Notification Service (알림)

**포트**: 8084  
**데이터베이스**: Redis (ElastiCache)  
**역할**: 실시간 알림 전송

**API**: POST `/notifications/send`, GET `/notifications/{employeeId}`  
**WebSocket**: `/ws/notifications` (SockJS + STOMP)

**특징**
- Redis Pub/Sub로 메시지 발행
- WebSocket 브로드캐스트 (모든 연결된 클라이언트)
- Public NLB로 노출 (WebSocket 지원)

---

## 로컬 개발

### 데이터베이스 실행

```bash
docker-compose up -d
```

### 서비스 빌드 및 실행

```bash
cd employee-service
mvn clean package -DskipTests
mvn spring-boot:run
```

### 테스트

```bash
curl -X POST http://localhost:8081/employees \
  -H "Content-Type: application/json" \
  -d '{"name":"김철수","department":"개발팀","position":"시니어"}'
```

---

## Docker 빌드

```bash
cd employee-service
docker build -t erp/employee-service:latest .

# ECR Push
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com
docker tag erp/employee-service:latest 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service:latest
docker push 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service:latest
```

---

## 환경 변수

**Employee Service**
- `SPRING_DATASOURCE_URL`: MySQL 연결 문자열
- `SPRING_DATASOURCE_USERNAME`: admin
- `SPRING_DATASOURCE_PASSWORD`: <secret>

**Approval Request Service**
- `SPRING_DATA_MONGODB_URI`: MongoDB Atlas 연결 문자열
- `EMPLOYEE_SERVICE_URL`: http://employee-service:8081
- `NOTIFICATION_SERVICE_URL`: http://notification-service:8084
- `GRPC_CLIENT_APPROVALPROCESSINGSERVICE_ADDRESS`: static://approval-processing-service:9090

**Approval Processing Service**
- `SPRING_DATA_REDIS_HOST`: Redis 엔드포인트
- `SPRING_DATA_REDIS_PORT`: 6379
- `GRPC_CLIENT_APPROVALREQUESTSERVICE_ADDRESS`: static://approval-request-service:9091

**Notification Service**
- `SPRING_DATA_REDIS_HOST`: Redis 엔드포인트
- `SPRING_DATA_REDIS_PORT`: 6379

---

## 트러블슈팅

**MySQL 연결 실패**
```bash
aws rds describe-db-instances --db-instance-identifier erp-dev-mysql
```

**gRPC 통신 실패**
```bash
kubectl logs -n erp-dev -l app=approval-processing-service | grep gRPC
```

**WebSocket 연결 실패**
- HTTP 페이지에서 접속 (ws:// 프로토콜)
- HTTPS 페이지에서는 연결 불가 (브라우저 보안 정책)

---

## 라이선스

MIT License
