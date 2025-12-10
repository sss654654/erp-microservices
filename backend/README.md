# ERP 백엔드 서비스

**아키텍처**: 마이크로서비스  
**프레임워크**: Spring Boot 3.3.5  
**언어**: Java 17  
**빌드 도구**: Maven  
**최종 업데이트**: 2025-12-10

---

## 📋 서비스 구성

### 1. Employee Service (직원 관리)

**포트**: 8081  
**데이터베이스**: MySQL (RDS)  
**역할**: 직원 정보 CRUD 및 검증

#### API 엔드포인트

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/employees` | 전체 직원 조회 |
| GET | `/employees/{id}` | 직원 상세 조회 |
| POST | `/employees` | 직원 생성 |
| PUT | `/employees/{id}` | 직원 수정 |
| DELETE | `/employees/{id}` | 직원 삭제 |

#### 환경 변수

```yaml
SPRING_DATASOURCE_URL: jdbc:mysql://erp-dev-mysql.cniqqqqiyu1n.ap-northeast-2.rds.amazonaws.com:3306/erp
SPRING_DATASOURCE_USERNAME: admin
SPRING_DATASOURCE_PASSWORD: <secret>
```

---

### 2. Approval Request Service (결재 요청)

**포트**: 8082 (HTTP), 9091 (gRPC Server)  
**데이터베이스**: MongoDB Atlas  
**역할**: 결재 요청 생성 및 관리

#### API 엔드포인트

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/approvals` | 전체 결재 조회 |
| GET | `/approvals/{requestId}` | 결재 상세 조회 |
| POST | `/approvals` | 결재 요청 생성 |
| DELETE | `/approvals` | 전체 결재 삭제 (테스트용) |

#### gRPC 서비스

```protobuf
service Approval {
  rpc ReturnApprovalResult(ApprovalResultRequest) returns (ApprovalResultResponse);
}
```

#### 환경 변수

```yaml
SPRING_DATA_MONGODB_URI: mongodb+srv://erp_user:***@erp-dev-cluster.4fboxqw.mongodb.net/erp
EMPLOYEE_SERVICE_URL: http://employee-service:8081
NOTIFICATION_SERVICE_URL: http://notification-service:8084
GRPC_CLIENT_APPROVALPROCESSINGSERVICE_ADDRESS: static://approval-processing-service:9090
```

---

### 3. Approval Processing Service (결재 처리)

**포트**: 8083 (HTTP), 9090 (gRPC Client)  
**데이터베이스**: Redis (ElastiCache)  
**역할**: 결재 대기 목록 관리 및 승인/반려 처리

#### API 엔드포인트

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/process/{approverId}` | 결재자 대기 목록 조회 |
| POST | `/process/{approverId}/{requestId}` | 결재 승인/반려 |

#### 환경 변수

```yaml
SPRING_DATA_REDIS_HOST: erp-dev-redis.jmz0hq.0001.apn2.cache.amazonaws.com
SPRING_DATA_REDIS_PORT: 6379
GRPC_CLIENT_APPROVALREQUESTSERVICE_ADDRESS: static://approval-request-service:9091
```

---

### 4. Notification Service (알림)

**포트**: 8084  
**데이터베이스**: Redis (ElastiCache)  
**역할**: 실시간 알림 전송 (WebSocket)

#### API 엔드포인트

| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/notifications/send` | 알림 발송 |
| GET | `/notifications/{employeeId}` | 알림 조회 |

#### WebSocket

- **Endpoint**: `/ws/notifications`
- **Protocol**: SockJS + STOMP
- **Subscribe**: `/topic/notifications`

#### 환경 변수

```yaml
SPRING_DATA_REDIS_HOST: erp-dev-redis.jmz0hq.0001.apn2.cache.amazonaws.com
SPRING_DATA_REDIS_PORT: 6379
```

---

## 🛠️ 로컬 개발

### 사전 요구사항

- Java 17
- Maven 3.8+
- Docker (로컬 데이터베이스)

### 1. 데이터베이스 실행

```bash
# Docker Compose로 MySQL, MongoDB, Redis 실행
docker-compose up -d

# 확인
docker ps
```

### 2. 서비스 빌드

```bash
# 전체 빌드
cd backend
mvn clean package -DskipTests

# 개별 서비스 빌드
cd employee-service
mvn clean package -DskipTests
```

### 3. 서비스 실행

```bash
# Employee Service
cd employee-service
mvn spring-boot:run

# Approval Request Service
cd approval-request-service
mvn spring-boot:run

# Approval Processing Service
cd approval-processing-service
mvn spring-boot:run

# Notification Service
cd notification-service
mvn spring-boot:run
```

### 4. 로컬 테스트

```bash
# 직원 생성
curl -X POST http://localhost:8081/employees \
  -H "Content-Type: application/json" \
  -d '{"name":"김철수","department":"개발팀","position":"시니어 개발자"}'

# 결재 요청
curl -X POST http://localhost:8082/approvals \
  -H "Content-Type: application/json" \
  -d '{
    "requesterId": 1,
    "title": "연차 신청",
    "content": "테스트",
    "steps": [{"step": 1, "approverId": 2}]
  }'
```

---

## 🐳 Docker 빌드

### Dockerfile

각 서비스의 Dockerfile:

```dockerfile
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 이미지 빌드

```bash
# Employee Service
cd employee-service
docker build -t erp/employee-service:latest .

# ECR Push
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com
docker tag erp/employee-service:latest 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service:latest
docker push 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service:latest
```

---

## 🧪 테스트

### 단위 테스트

```bash
mvn test
```

### 통합 테스트

```bash
mvn verify
```

### Postman Collection

```bash
# Import
backend/ERP_Postman_Collection.json
```

---

## 📊 모니터링

### 로그 확인

```bash
# 로컬
tail -f logs/application.log

# Kubernetes
kubectl logs -n erp-dev -l app=employee-service --tail=50
```

### Health Check

```bash
curl http://localhost:8081/actuator/health
```

---

## 🔧 설정

### application.yml

각 서비스의 `src/main/resources/application.yml`:

```yaml
spring:
  application:
    name: employee-service
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true

server:
  port: 8081

logging:
  level:
    com.erp: DEBUG
```

---

## 🐛 트러블슈팅

### MySQL 연결 실패

```bash
# RDS 엔드포인트 확인
aws rds describe-db-instances \
  --db-instance-identifier erp-dev-mysql \
  --query "DBInstances[0].Endpoint.Address" \
  --output text

# Security Group 확인
aws ec2 describe-security-groups \
  --group-ids <sg-id> \
  --region ap-northeast-2
```

### MongoDB 연결 실패

```bash
# MongoDB Atlas 연결 문자열 확인
kubectl get configmap erp-config -n erp-dev -o jsonpath='{.data.MONGODB_URI}'
```

### gRPC 통신 실패

```bash
# gRPC 포트 확인
kubectl get svc -n erp-dev | grep approval

# 로그 확인
kubectl logs -n erp-dev -l app=approval-processing-service | grep gRPC
```

---

## 📚 참고 자료

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [gRPC Java](https://grpc.io/docs/languages/java/)
- [MongoDB Java Driver](https://www.mongodb.com/docs/drivers/java/)
- [Spring Data Redis](https://spring.io/projects/spring-data-redis)

---

## 📄 라이선스

MIT License
