# ERP 백엔드 서비스

**프레임워크**: Spring Boot 3.3.5  
**언어**: Java 17  
**빌드**: Maven  
**최종 업데이트**: 2025-12-11 (3단계: Kafka 통합)

---

## 📌 주요 변경사항 (3단계)

### 통신 방식 변경: gRPC → Kafka

#### 2단계: gRPC 동기 통신의 한계

```
Approval Request Service
  ↓ gRPC 동기 호출 (Blocking)
  ↓ 응답 대기... (850ms)
Approval Processing Service
```

**측정 결과:**
- 평균 응답 시간: 850ms
- 에러율: 5% (타임아웃)
- 처리량: 35 req/sec
- **문제**: Processing Service 다운 시 Request Service도 실패

#### 3단계: Kafka 비동기 메시징으로 전환

```
Approval Request Service
  ↓ Kafka Produce (비동기, 즉시 반환)
Kafka Topic (approval-requests)
  ↓ Consumer Group (병렬 처리)
Approval Processing Service
```

**개선 결과:**

| 항목 | 2단계 (gRPC) | 3단계 (Kafka) | 개선율 |
|------|-------------|---------------|--------|
| **통신 방식** | 동기 (Blocking) | 비동기 (Non-blocking) | - |
| **평균 응답 시간** | 850ms | 120ms | 85% ↓ |
| **처리량** | 35 req/sec | 250 req/sec | 614% ↑ |
| **에러율** | 5% | 0% | 100% ↓ |
| **장애 격리** | 없음 | 메시지 보존 | ✅ |

**핵심 개선:**
- Request Service는 Kafka에 메시지만 전송하고 즉시 반환 (120ms)
- Processing Service가 다운되어도 메시지는 Kafka에 보존
- Consumer Group으로 병렬 처리 (처리량 614% 증가)
- Offset 관리로 재처리 가능

#### Kinesis vs Kafka 선택

**CGV 프로젝트 (Kinesis):**
- 단일 서비스 내 대기열 (API 서버 → Kinesis → 동일 서버)
- 대량 트래픽 버퍼링 목적
- 단일 Consumer

**ERP 프로젝트 (Kafka):**
- 서비스 간 메시징 (Request → Kafka → Processing)
- 비동기 통신 목적
- Consumer Group (병렬 처리)

**선택 이유:**
- 마이크로서비스 환경에서는 Consumer Group과 Offset 관리가 유리
- Kafka on EKS: MSK $300/월 대신 기존 EKS 노드 활용 (추가 비용 없음)

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

## 🎮 추가 구현 (3단계: 창의 영역)

### 게이미피케이션 퀘스트 시스템

#### 개념
직원의 출석과 업무 수행을 게임화하여 연차를 보상으로 지급하는 시스템

#### 1. 기본 퀘스트 (자동)
- **30일 출석 달성**: 출석 30일마다 연차 1일 자동 지급
- **진행률 표시**: 실시간 진행률 (예: 15/30 = 50%)
- **자동 리셋**: 30일 달성 시 0으로 리셋, 다시 시작

#### 2. 커스텀 퀘스트 (부장 생성)
- **부장**: 업무 생성 (제목, 내용, 보상 연차)
- **사원**: 업무 수락 → 오프라인 수행 → 완료 보고
- **부장**: 확인 후 승인 → 사원 연차 지급 활성화
- **사원**: 보상 받기 클릭 → 연차 추가

#### 퀘스트 API

**출석 퀘스트:**
```bash
# 출근 (출석 +1, 30일마다 연차 +1)
POST /attendance/check-in/{employeeId}
Response: {
  "attendanceCount": 16,
  "questProgress": 53,
  "rewardEarned": false,
  "currentLeaveBalance": 3.0
}

# 진행률 조회
GET /attendance/progress/{employeeId}
Response: {
  "attendanceCount": 16,
  "targetCount": 30,
  "progress": 53,
  "nextRewardAt": 14
}
```

**커스텀 퀘스트 (사원):**
```bash
# 가능한 업무 목록
GET /quests/available?employeeId=1

# 업무 수락
POST /quests/{questId}/accept
Body: { "employeeId": 1 }

# 완료 보고
POST /quests/{questId}/complete
Body: { "employeeId": 1 }

# 내 퀘스트 목록
GET /quests/my-quests?employeeId=1

# 보상 받기
POST /quests/{questId}/claim
Body: { "employeeId": 1 }
```

**커스텀 퀘스트 (부장):**
```bash
# 업무 생성
POST /quests
Body: {
  "title": "커피 끓여오기",
  "description": "아메리카노 2잔",
  "rewardDays": 0.5,
  "department": "DEVELOPMENT",
  "createdBy": 2
}

# 내가 만든 업무
GET /quests/my-created?managerId=2

# 승인
PUT /quests/{questId}/approve
Body: { "managerId": 2 }

# 반려
PUT /quests/{questId}/reject
Body: { "managerId": 2, "reason": "다시 해주세요" }

# 삭제
DELETE /quests/{questId}
```

**팀 관리 (부장):**
```bash
# 팀원 목록 조회
GET /employees/team?department=DEVELOPMENT

# 연차 수동 조정
PUT /employees/{id}/leave-balance
Body: { "managerId": 2, "adjustment": 1 }  # +1 or -1
```

#### 퀘스트 상태 흐름
```
AVAILABLE (생성됨)
  ↓ accept
IN_PROGRESS (진행 중)
  ↓ complete
WAITING_APPROVAL (승인 대기)
  ↓ approve
APPROVED (승인됨)
  ↓ claim
CLAIMED (보상 받음)
```

#### 데이터베이스 테이블

**quests:**
```sql
- id: 퀘스트 ID
- title: 제목
- description: 설명
- reward_days: 보상 연차 (0.5, 1.0 등)
- department: 부서
- created_by: 생성자 (부장 ID)
- status: AVAILABLE, DELETED
```

**quest_progress:**
```sql
- id: 진행 ID
- quest_id: 퀘스트 ID
- employee_id: 직원 ID
- status: IN_PROGRESS, WAITING_APPROVAL, APPROVED, REJECTED, CLAIMED
- accepted_at: 수락 시간
- completed_at: 완료 시간
- approved_at: 승인 시간
- claimed_at: 보상 받은 시간
```

**employees (추가 필드):**
```sql
- email: 이메일 (unique)
- annual_leave_balance: 보유 연차
- attendance_count: 출석 일수
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
