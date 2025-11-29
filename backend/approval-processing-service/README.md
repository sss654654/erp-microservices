# Approval Processing Service

결재 승인/반려 처리 로직을 담당하는 서비스입니다.

## 역할

- Approval Request Service로부터 gRPC 호출을 받아 결재 대기열 관리
- 결재자의 승인/반려 요청을 처리
- 처리 결과를 gRPC로 Approval Request Service에 회신

## 기술 스택

- **언어/프레임워크**: Java 17, Spring Boot 3.3.5
- **통신**: gRPC Server + gRPC Client, REST API
- **저장소**: In-Memory (ConcurrentHashMap)

## 아키텍처

```
[Approval Request Service]
         |
         | gRPC: RequestApproval
         v
[Approval Processing Service]
         |
         | In-Memory 저장 (approverId별 대기 목록)
         |
         | REST: POST /process/{approverId}/{requestId}
         v
[결재자가 승인/반려]
         |
         | gRPC: ReturnApprovalResult
         v
[Approval Request Service]
```

## In-Memory 저장 구조

```java
Map<Integer, List<ApprovalRequest>> approverQueue
// Key: approverId (결재자 ID)
// Value: 해당 결재자의 대기 목록
```

**예시**:
```json
{
  "7": [
    {
      "requestId": 1,
      "requesterId": 1,
      "title": "Expense Report",
      "content": "Travel expenses",
      "steps": [
        {"step": 1, "approverId": 3, "status": "approved"},
        {"step": 2, "approverId": 7, "status": "pending"}
      ]
    }
  ]
}
```

## gRPC 프로토콜

### 1. RequestApproval (수신)

Approval Request Service로부터 결재 정보를 받아 인메모리에 저장합니다.

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

**처리 흐름**:
1. steps 배열에서 첫 번째 "pending" 상태의 approverId 찾기
2. 해당 approverId를 키로 하는 대기 리스트에 저장
3. "received" 응답 반환

### 2. ReturnApprovalResult (송신)

결재 처리 결과를 Approval Request Service에 전달합니다.

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

## REST API

### 1. GET /process/{approverId}

결재자의 대기 목록을 조회합니다.

**Request**:
```bash
GET http://localhost:8083/process/7
```

**Response**:
```json
[
  {
    "requestId": 1,
    "requesterId": 1,
    "title": "Expense Report",
    "content": "Travel expenses",
    "steps": [
      {"step": 1, "approverId": 3, "status": "approved"},
      {"step": 2, "approverId": 7, "status": "pending"}
    ]
  }
]
```

### 2. POST /process/{approverId}/{requestId}

결재를 승인 또는 반려합니다.

**Request**:
```bash
POST http://localhost:8083/process/7/1
Content-Type: application/json

{
  "status": "approved"
}
```

**Response**:
```json
{
  "message": "Approval processed",
  "requestId": 1,
  "status": "approved"
}
```

**처리 흐름**:
1. 인메모리에서 해당 결재 건 찾기
2. 대기 목록에서 제거
3. gRPC로 Approval Request Service에 결과 전송 (ReturnApprovalResult)

## 포트

- REST API: 8083
- gRPC Server: 9090

## 실행 방법

### 로컬 실행
```bash
cd approval-processing-service
mvn clean package
java -jar target/approval-processing-service-1.0.0.jar
```

### Docker 실행
```bash
docker build -t approval-processing-service .
docker run -p 8083:8083 -p 9090:9090 approval-processing-service
```

## 환경 변수

```yaml
GRPC_CLIENT_APPROVAL_REQUEST_SERVICE_ADDRESS: static://localhost:9091
```

## 의존성

- Approval Request Service (gRPC Client로 연결)
