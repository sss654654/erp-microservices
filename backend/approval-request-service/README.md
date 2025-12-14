# Approval Request Service

결재 요청 생성 및 관리를 담당하는 마이크로서비스

## 책임

- 결재 요청 생성 (다단계 승인 플로우)
- 결재 요청 조회 (전체, 요청자별, 결재자별)
- Kafka Producer (approval-requests 토픽으로 메시지 발행)
- Kafka Consumer (approval-results 토픽에서 결과 수신)
- 결재 완료 시 Employee Service에 연차 차감 요청

## 기술 스택

- **Framework**: Spring Boot 3.3.5
- **Database**: MongoDB Atlas (M0 Free Tier)
- **Messaging**: Apache Kafka 3.6.0
- **Port**: 8082

## 데이터베이스 스키마 (MongoDB)

### approval_requests Collection
```json
{
  "_id": "ObjectId",
  "requestId": 1,
  "requesterId": 123,
  "title": "연차 신청",
  "content": "2025-12-20 ~ 2025-12-22 (3일)",
  "type": "ANNUAL_LEAVE",
  "leaveDays": 3.0,
  "steps": [
    {
      "step": 1,
      "approverId": 456,
      "status": "approved",
      "updatedAt": "2025-12-14T10:00:00"
    },
    {
      "step": 2,
      "approverId": 789,
      "status": "pending",
      "updatedAt": null
    }
  ],
  "finalStatus": "in_progress",
  "createdAt": "2025-12-14T09:00:00",
  "updatedAt": "2025-12-14T10:00:00"
}
```

## 주요 API

- `POST /approvals` - 결재 요청 생성
- `GET /approvals` - 전체 결재 요청 조회
- `GET /approvals/requester/{requesterId}` - 요청자별 조회
- `GET /approvals/approver/{approverId}` - 결재자별 조회 (내가 결재할 건)
- `GET /approvals/{requestId}` - 결재 요청 상세 조회

## Kafka 통신

### Producer (approval-requests 토픽)
```java
@Component
public class ApprovalRequestProducer {
    private final KafkaTemplate<String, Object> kafkaTemplate;
    
    public void sendApprovalRequest(ApprovalRequestMessage message) {
        String key = String.valueOf(message.getRequestId());
        kafkaTemplate.send("approval-requests", key, message);
    }
}
```

**메시지 구조**:
```json
{
  "requestId": 1,
  "requesterId": 123,
  "title": "연차 신청",
  "content": "2025-12-20 ~ 2025-12-22 (3일)",
  "steps": [
    {"step": 1, "approverId": 456, "status": "pending"},
    {"step": 2, "approverId": 789, "status": "pending"}
  ],
  "timestamp": "2025-12-14T09:00:00"
}
```

### Consumer (approval-results 토픽)
```java
@Component
public class ApprovalResultConsumer {
    @KafkaListener(topics = "approval-results", groupId = "approval-request-group")
    public void consumeApprovalResult(ApprovalResultMessage message) {
        requestService.handleApprovalResult(
            message.getRequestId(),
            message.getStep(),
            message.getApproverId(),
            message.getStatus()
        );
    }
}
```

**메시지 구조**:
```json
{
  "requestId": 1,
  "step": 1,
  "approverId": 456,
  "status": "approved",
  "timestamp": "2025-12-14T10:00:00"
}
```

## 핵심 로직

### 결재 요청 생성 및 Kafka 발행
```java
public ApprovalRequest createApproval(CreateApprovalRequest request) {
    // 1. 직원 검증 (Employee Service 호출)
    employeeClient.validateEmployee(request.getRequesterId());
    
    // 2. MongoDB에 저장
    ApprovalRequest approval = new ApprovalRequest();
    approval.setRequestId(sequenceGenerator.generateSequence("approval_request_seq"));
    approval.setRequesterId(request.getRequesterId());
    approval.setTitle(request.getTitle());
    approval.setSteps(request.getSteps());
    approval.setFinalStatus("in_progress");
    ApprovalRequest saved = repository.save(approval);
    
    // 3. Kafka로 Processing Service에 전달
    ApprovalRequestMessage message = new ApprovalRequestMessage(saved);
    approvalRequestProducer.sendApprovalRequest(message);
    
    return saved;
}
```

### 결재 결과 처리 및 연차 차감
```java
public void handleApprovalResult(Integer requestId, Integer step, Integer approverId, String status) {
    ApprovalRequest approval = repository.findByRequestId(requestId).orElseThrow();
    
    // 해당 단계 상태 업데이트
    approval.getSteps().stream()
        .filter(s -> s.getStep().equals(step) && s.getApproverId().equals(approverId))
        .findFirst()
        .ifPresent(s -> {
            s.setStatus(status);
            s.setUpdatedAt(LocalDateTime.now());
        });
    
    // 반려 시 최종 상태 업데이트
    if ("rejected".equals(status)) {
        approval.setFinalStatus("rejected");
    }
    // 모든 단계 승인 완료 시
    else if (approval.getSteps().stream().allMatch(s -> "approved".equals(s.getStatus()))) {
        approval.setFinalStatus("approved");
        
        // 연차 유형이면 Employee Service에 연차 차감 요청
        if ("ANNUAL_LEAVE".equals(approval.getType())) {
            restTemplate.postForEntity(
                employeeServiceUrl + "/employees/" + approval.getRequesterId() + "/deduct-leave",
                Map.of("days", approval.getLeaveDays()),
                Map.class
            );
        }
    }
    
    repository.save(approval);
}
```

## 로컬 실행

```bash
# MongoDB 실행 (Docker)
docker run -d -p 27017:27017 mongo:7.0

# Kafka 실행 (Docker Compose)
docker-compose up -d kafka zookeeper

# 애플리케이션 실행
mvn spring-boot:run
```

## 환경 변수

```yaml
SPRING_DATA_MONGODB_URI: mongodb://localhost:27017/erp
KAFKA_BOOTSTRAP_SERVERS: localhost:9092
EMPLOYEE_SERVICE_URL: http://localhost:8081
```
