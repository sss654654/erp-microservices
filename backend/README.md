# Backend Services

ERP 시스템의 백엔드는 4개의 독립적인 마이크로서비스로 구성되어 있습니다.

## 구조

```
backend/
├── employee-service/           # 직원 관리 (MySQL)
├── approval-request-service/   # 결재 요청 생성 및 저장 (MongoDB)
├── approval-processing-service/# 결재 처리 로직 (In-Memory)
├── notification-service/        # 알림 전송 (Redis + WebSocket)
├── proto/                       # gRPC Proto 파일 (공유)
├── docker-compose.yml           # 로컬 개발 환경
└── ERP_Postman_Collection.json # API 테스트 컬렉션
```

## 서비스별 역할

### Employee Service (Port 8081)
- 직원 정보 CRUD
- MySQL 사용
- REST API 제공

### Approval Request Service (Port 8082)
- 결재 요청 생성 및 조회
- MongoDB 사용
- gRPC Client (Processing Service 호출)
- gRPC Server (결과 수신)

### Approval Processing Service (Port 8083)
- 결재 승인/반려 처리
- In-Memory 저장 (ConcurrentHashMap)
- gRPC Server (요청 수신)
- gRPC Client (결과 반환)

### Notification Service (Port 8084)
- 실시간 알림 전송
- Redis 저장 (TTL 7일)
- WebSocket (STOMP)

## 통신 방식

- **REST**: Frontend ↔ Backend, Service ↔ Notification
- **gRPC**: Approval Request ↔ Approval Processing (양방향)
- **WebSocket**: Frontend ↔ Notification (실시간)

## 로컬 실행

```bash
# Docker Compose로 전체 실행
docker-compose up -d

# 개별 서비스 빌드 및 실행
cd employee-service
mvn clean package
java -jar target/employee-service-0.0.1-SNAPSHOT.jar
```

## AWS 배포

각 서비스는 독립적인 CI/CD 파이프라인을 가지고 있습니다:
- CodePipeline: GitHub Push 감지
- CodeBuild: Docker 이미지 빌드 (buildspec.yml)
- ECR: 이미지 저장
- EKS: Kubernetes 자동 배포

## API 테스트

Postman Collection을 Import하여 테스트:
```bash
# ERP_Postman_Collection.json
```

## 환경 변수

각 서비스는 Kubernetes Secret에서 환경 변수를 주입받습니다:
- `MYSQL_URL`, `MYSQL_PASSWORD`
- `MONGODB_URI`
- `REDIS_HOST`, `REDIS_PORT`
- `GRPC_SERVER_PORT`
