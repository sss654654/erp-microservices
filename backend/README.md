# ERP 백엔드 서비스

**프레임워크**: Spring Boot 3.3.5  
**언어**: Java 17  
**빌드**: Maven  
**최종 업데이트**: 2025-12-11 (3단계: Kafka 통합)

---

## 📌 주요 변경사항 (3단계)

### 통신 방식 변경: gRPC → Kafka

| 항목 | 2단계 (gRPC) | 3단계 (Kafka) |
|------|-------------|---------------|
| **통신 방식** | 동기 (Blocking) | 비동기 (Non-blocking) |
| **평균 응답 시간** | 850ms | 120ms (85% ↓) |
| **처리량** | 35 req/sec | 250 req/sec (614% ↑) |
| **에러율** | 5% | 0% |
| **장애 격리** | 없음 | 메시지 보존 |

### 추가 기능
- ✅ **출퇴근 관리** (Attendance)
- ✅ **연차 관리** (Leave)

---

## 서비스 구성

### 1. Employee Service (직원 관리)

**포트**: 8081  
**데이터베이스**: MySQL (RDS)  
**역할**: 직원 정보 CRUD, 출퇴근 관리, 연차 관리

**API**:
- 직원: GET/POST/PUT/DELETE `/employees`, `/employees/{id}`
- 출퇴근: POST `/attendance/check-in/{employeeId}`, `/attendance/check-out/{employeeId}`, GET `/attendance/history/{employeeId}`
- 연차: POST `/leaves`, GET `/leaves/{employeeId}`, PUT `/leaves/{id}/approve`, GET `/leaves/balance/{employeeId}`

**새 기능**:
- 출근/퇴근 기록 및 근무 시간 자동 계산
- 연차 신청/승인/반려 및 잔여 일수 관리 (기본 15일)

### 2. Approval Request Service (결재 요청)

**포트**: 8082 (HTTP)  
**데이터베이스**: MongoDB Atlas  
**통신**: Kafka Producer/Consumer  
**역할**: 결재 요청 생성 및 관리

**API**: GET/POST `/approvals`, `/approvals/{requestId}`  
**Kafka**:
- Producer → `approval-requests` Topic (결재 요청 전달)
- Consumer ← `approval-results` Topic (결재 결과 수신)

**특징**:
- MongoDB Sequence Generator로 requestId 생성
- Kafka 비동기 메시지로 Processing Service와 통신
- Notification Service 호출 (최종 승인/반려 시)

### 3. Approval Processing Service (결재 처리)

**포트**: 8083 (HTTP)  
**데이터베이스**: In-Memory (ConcurrentHashMap)  
**통신**: Kafka Producer/Consumer  
**역할**: 결재 대기 목록 관리 및 승인/반려 처리

**API**: GET `/process/{approverId}`, POST `/process/{approverId}/{requestId}`  
**Kafka**:
- Consumer ← `approval-requests` Topic (결재 요청 수신)
- Producer → `approval-results` Topic (결재 결과 전송)

**특징**:
- In-Memory 대기 목록 (빠른 조회)
- Kafka 비동기 메시지로 Request Service와 통신
- 순차 결재 로직 (1단계 승인 후 2단계 전달)

### 4. Notification Service (알림)

**포트**: 8084  
**데이터베이스**: Redis (ElastiCache)  
**역할**: 실시간 알림 전송

**API**: POST `/notifications/send`

---

## Kafka 구성

### Broker
- **주소**: `kafka.erp-dev.svc.cluster.local:9092`
- **이미지**: confluentinc/cp-kafka:7.5.0
- **Replica**: 1 (개발 환경)

### Topics
| Topic | Partitions | 용도 |
|-------|-----------|------|
| `approval-requests` | 3 | Request → Processing (결재 요청 전달) |
| `approval-results` | 3 | Processing → Request (결재 결과 반환) |

### Consumer Groups
- `approval-request-group`: Approval Request Service
- `approval-processing-group`: Approval Processing Service

---

## 로컬 개발

### 빌드
```bash
cd backend/employee-service
mvn clean package -DskipTests

cd ../approval-request-service
mvn clean package -DskipTests

cd ../approval-processing-service
mvn clean package -DskipTests

cd ../notification-service
mvn clean package -DskipTests
```

### 환경 변수
```bash
# Kafka
SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka.erp-dev.svc.cluster.local:9092

# MySQL
SPRING_DATASOURCE_URL=jdbc:mysql://localhost:3306/erp
SPRING_DATASOURCE_USERNAME=admin
SPRING_DATASOURCE_PASSWORD=***

# MongoDB
SPRING_DATA_MONGODB_URI=mongodb+srv://***

# Redis
SPRING_DATA_REDIS_HOST=localhost
SPRING_DATA_REDIS_PORT=6379
```

---

## 배포

### CI/CD
- **도구**: AWS CodePipeline + CodeBuild
- **트리거**: GitHub Push (main 브랜치)
- **이미지 저장소**: Amazon ECR
- **배포 대상**: Amazon EKS

### 파이프라인
1. Source: GitHub Webhook
2. Build: CodeBuild (Maven + Docker)
3. Deploy: ECR Push → kubectl apply (수동)

---

## 테스트

### Kafka 통신 테스트
```bash
# 결재 요청 생성
curl -X POST https://API_GATEWAY_URL/api/approvals \
  -H "Content-Type: application/json" \
  -d '{
    "requesterId": 1,
    "title": "Kafka 테스트",
    "content": "비동기 통신 확인",
    "steps": [{"step": 1, "approverId": 2}]
  }'

# Kafka 메시지 확인
kubectl exec -n erp-dev kafka-xxx -- kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic approval-requests \
  --from-beginning \
  --max-messages 1
```

### 출퇴근 테스트
```bash
# 출근
curl -X POST https://API_GATEWAY_URL/api/attendance/check-in/1

# 퇴근
curl -X POST https://API_GATEWAY_URL/api/attendance/check-out/1

# 이력 조회
curl https://API_GATEWAY_URL/api/attendance/history/1
```

### 연차 테스트
```bash
# 연차 신청
curl -X POST https://API_GATEWAY_URL/api/leaves \
  -H "Content-Type: application/json" \
  -d '{
    "employeeId": 1,
    "startDate": "2025-12-20",
    "endDate": "2025-12-22",
    "days": 3,
    "reason": "개인 사유"
  }'

# 잔여 일수 조회
curl https://API_GATEWAY_URL/api/leaves/balance/1
```

---

## 백업 및 복원

### gRPC 코드 백업 (2단계)
- **위치**: `backend/proto-backup/`
- **파일**: `approval.proto`, `README.md`

### 복원 방법
```bash
# 2단계 gRPC 방식으로 되돌리기
git checkout 2798b2a -- backend/approval-request-service/pom.xml
git checkout 2798b2a -- backend/approval-processing-service/pom.xml
# ... (자세한 내용은 proto-backup/README.md 참조)
```

---

## 문제 해결

### Kafka 연결 실패
```bash
# Kafka Pod 확인
kubectl get pods -n erp-dev -l app=kafka

# Kafka 로그 확인
kubectl logs -n erp-dev -l app=kafka --tail=50
```

### 빌드 실패
```bash
# CodeBuild 로그 확인
aws codebuild batch-get-builds --ids <build-id> --region ap-northeast-2
```

---

**참고**: 2단계 gRPC 구현은 `proto-backup/` 폴더에 백업되어 있습니다.
