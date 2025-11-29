# Approval Request Service

결재 요청 생성 및 결재 단계 관리를 담당하는 서비스입니다.

## 역할

- 결재 요청 생성, 조회
- Employee Service 연동 (직원 검증)
- Approval Processing Service 연동 (gRPC 양방향 통신)
- 결재 상태 관리 (in_progress, approved, rejected)

## 기술 스택

- **언어/프레임워크**: Java 17, Spring Boot 3.3.5
- **데이터베이스**: MongoDB
- **통신**: REST API, gRPC Client + gRPC Server

## 아키텍처

```
[Client]
   |
   | POST /approvals
   v
[Approval Request Service]
   |
   | 1. REST: 직원 검증
   v
[Employee Service]
   |
   v
[Approval Request Service]
   |
   | 2. MongoDB 저장 (PENDING)
   | 3. gRPC: RequestApproval
   v
[Approval Processing Service]
   |
   | 4. 결재자가 승인/반려
   | 5. gRPC: ReturnApprovalResult
   v
[Approval Request Service]
   |
   | 6. MongoDB 상태 업데이트
   | 7. 다음 단계 or 완료 처리
   v
[Notification Service]
```

## MongoDB Document 구조

```javascript
{
  "_id": ObjectId("..."),
  "requestId": 1,
  "requesterId": 1,
  "title": "Expense Report",
  "content": "Travel expenses",
  "steps": [
    {
      "step": 1,
      "approverId": 3,
      "status": "approved",
      "updatedAt": "2025-01-01T11:23:11Z"
    },
    {
      "step": 2,
      "approverId": 7,
      "status": "pending"
    }
  ],
  "finalStatus": "in_progress",
  "createdAt": "2025-01-01T10:23:11Z",
  "updatedAt": "2025-01-01T11:23:11Z"
}
```

**필드 설명**:
- `requestId`: 자동 생성되는 결재 요청 ID
- `requesterId`: 요청한 직원 ID
- `steps`: 결재자 순서 및 단계별 상태
- `finalStatus`: 최종 상태 (in_progress, approved, rejected)

## REST API

### 1. POST /approvals

결재 요청을 생성합니다.

**Request**:
```json
{
  "requesterId": 1,
  "title": "Expense Report",
  "content": "Travel expenses",
  "steps": [
    {"step": 1, "approverId": 3},
    {"step": 2, "approverId": 7}
  ]
}
```

**Response**:
```json
{
  "requestId": 1
}
```

**처리 흐름**:
1. Employee Service에서 requesterId, approverId 검증 (REST)
2. steps가 1부터 오름차순인지 검증
3. MongoDB에 저장 (모든 steps는 "pending" 상태)
4. gRPC로 Approval Processing Service에 RequestApproval 호출

### 2. GET /approvals

모든 결재 요청 목록을 조회합니다.

**Request**:
```bash
GET http://localhost:8082/approvals
```

**Response**:
```json
[
  {
    "requestId": 1,
    "requesterId": 1,
    "title": "Expense Report",
    "steps": [...],
    "finalStatus": "in_progress"
  }
]
```

### 3. GET /approvals/{requestId}

특정 결재 요청을 조회합니다.

**Request**:
```bash
GET http://localhost:8082/approvals/1
```

## gRPC 프로토콜

### 1. RequestApproval (송신)

Approval Processing Service에 결재 정보를 전달합니다.

**Request**:
```protobuf
message ApprovalRequest {
  int32 requestId = 1;
  int32 requesterId = 2;
  string title = 3;
  string content = 4;
  repeated Step steps = 5;
}
```

**Response**:
```protobuf
message ApprovalResponse {
  string status = 1; // "received"
}
```

### 2. ReturnApprovalResult (수신)

Approval Processing Service로부터 결재 결과를 받습니다.

**Request**:
```protobuf
message ApprovalResultRequest {
  int32 requestId = 1;
  int32 step = 2;
  int32 approverId = 3;
  string status = 4; // "approved" or "rejected"
}
```

**Response**:
```protobuf
message ApprovalResultResponse {
  string status = 1; // "processed"
}
```

**처리 흐름**:
1. MongoDB에서 해당 requestId 찾기
2. 해당 step의 status 업데이트 + updatedAt 추가
3. **status가 "rejected"인 경우**:
   - finalStatus를 "rejected"로 변경
   - Notification Service 호출 (요청자에게 반려 알림)
4. **status가 "approved"인 경우**:
   - 다음 pending 단계가 있으면:
     - RequestApproval 재호출 (다음 결재자에게 전달)
   - 모든 단계가 완료되면:
     - finalStatus를 "approved"로 변경
     - Notification Service 호출 (요청자에게 승인 완료 알림)

## 포트

- REST API: 8082
- gRPC Server: 9091

## 실행 방법

### 로컬 실행
```bash
cd approval-request-service
mvn clean package
java -jar target/approval-request-service-1.0.0.jar
```

### Docker 실행
```bash
docker build -t approval-request-service .
docker run -p 8082:8082 -p 9091:9091 \
  -e SPRING_DATA_MONGODB_HOST=mongodb \
  approval-request-service
```

## 환경 변수

```yaml
SPRING_DATA_MONGODB_HOST: mongodb
SPRING_DATA_MONGODB_PORT: 27017
SPRING_DATA_MONGODB_DATABASE: erp
GRPC_CLIENT_APPROVAL_PROCESSING_SERVICE_ADDRESS: static://localhost:9090
```

## 의존성

- Employee Service (REST Client)
- Approval Processing Service (gRPC Client + Server)
- MongoDB
- Notification Service (REST Client)
