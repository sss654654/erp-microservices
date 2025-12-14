# Approval Processing Service

결재 처리 로직 및 대기 큐 관리를 담당하는 마이크로서비스

## 책임

- 결재 대기 큐 관리 (결재자별 ConcurrentHashMap)
- Kafka Consumer (approval-requests 토픽에서 요청 수신)
- Kafka Producer (approval-results 토픽으로 결과 발행)
- 결재 승인/반려 처리

## 기술 스택

- **Framework**: Spring Boot 3.3.5
- **Database**: In-Memory (ConcurrentHashMap)
- **Messaging**: Apache Kafka 3.6.0
- **Port**: 8083

## 데이터 구조

### ConcurrentHashMap 기반 대기 큐
```java
// 결재자별 대기 큐 (approverId → List<ApprovalRequest>)
private final Map<Integer, List<ApprovalRequestMessage>> approverQueue = new ConcurrentHashMap<>();
```

**장점**:
- O(1) 시간 복잡도로 결재자별 큐 조회
- Thread-safe (ConcurrentHashMap + CopyOnWriteArrayList)
- Redis 네트워크 비용 없음

## 주요 API

- `GET /processing/queue/{approverId}` - 결재자별 대기 큐 조회
- `POST /processing/approve` - 결재 승인 처리
- `POST /processing/reject` - 결재 반려 처리

## Kafka 통신

### Consumer (approval-requests 토픽)
```java
@Component
public class ApprovalRequestConsumer {
    @KafkaListener(topics = "approval-requests", groupId = "approval-processing-group")
    public void consumeApprovalRequest(ApprovalRequestMessage message) {
        processingService.addToQueue(message);
    }
}
```

### Producer (approval-results 토픽)
```java
@Component
public class ApprovalResultProducer {
    private final KafkaTemplate<String, Object> kafkaTemplate;
    
    public void sendApprovalResult(ApprovalResultMessage message) {
        String key = String.valueOf(message.getRequestId());
        kafkaTemplate.send("approval-results", key, message);
    }
}
```

## 핵심 로직

### 대기 큐에 추가
```java
public void addToQueue(ApprovalRequestMessage message) {
    // 첫 번째 pending 단계 찾기
    Optional<StepDto> firstPending = message.getSteps().stream()
        .filter(s -> "pending".equals(s.getStatus()))
        .findFirst();
    
    if (firstPending.isPresent()) {
        Integer approverId = firstPending.get().getApproverId();
        approverQueue.computeIfAbsent(approverId, k -> new CopyOnWriteArrayList<>()).add(message);
        log.info("Added to queue: approverId={}, requestId={}", approverId, message.getRequestId());
    }
}
```

### 결재 처리 및 Kafka 발행
```java
public boolean processApproval(Integer approverId, Integer requestId, String status) {
    List<ApprovalRequestMessage> queue = approverQueue.get(approverId);
    if (queue == null) return false;
    
    // 대기 큐에서 해당 요청 찾기
    Optional<ApprovalRequestMessage> requestOpt = queue.stream()
        .filter(r -> r.getRequestId().equals(requestId))
        .findFirst();
    
    if (requestOpt.isEmpty()) return false;
    
    ApprovalRequestMessage request = requestOpt.get();
    
    // 현재 결재 단계 찾기
    Optional<StepDto> currentStepOpt = request.getSteps().stream()
        .filter(step -> step.getApproverId().equals(approverId) && "pending".equals(step.getStatus()))
        .findFirst();
    
    if (currentStepOpt.isEmpty()) return false;
    
    StepDto currentStep = currentStepOpt.get();
    
    // 대기 목록에서 제거
    queue.remove(request);
    
    // Kafka로 결과 전송
    ApprovalResultMessage resultMessage = new ApprovalResultMessage(
        requestId,
        currentStep.getStep(),
        approverId,
        status,
        LocalDateTime.now()
    );
    resultProducer.sendApprovalResult(resultMessage);
    
    return true;
}
```

### 결재자별 대기 큐 조회
```java
public List<Map<String, Object>> getQueue(Integer approverId) {
    return approverQueue.getOrDefault(approverId, List.of()).stream()
        .map(req -> Map.of(
            "requestId", (Object) req.getRequestId(),
            "requesterId", req.getRequesterId(),
            "title", req.getTitle(),
            "content", req.getContent(),
            "steps", req.getSteps()
        ))
        .collect(Collectors.toList());
}
```

## 동작 흐름

```
1. Kafka Consumer가 approval-requests 토픽에서 메시지 수신
   ↓
2. 첫 번째 pending 단계의 결재자 ID 추출
   ↓
3. ConcurrentHashMap에 결재자별로 큐에 추가
   ↓
4. 결재자가 /processing/approve 또는 /processing/reject 호출
   ↓
5. 큐에서 해당 요청 제거
   ↓
6. Kafka Producer가 approval-results 토픽으로 결과 발행
   ↓
7. Approval Request Service가 결과 수신 및 MongoDB 업데이트
```

## 로컬 실행

```bash
# Kafka 실행 (Docker Compose)
docker-compose up -d kafka zookeeper

# 애플리케이션 실행
mvn spring-boot:run
```

## 환경 변수

```yaml
KAFKA_BOOTSTRAP_SERVERS: localhost:9092
```

## 왜 Redis 대신 In-Memory를 사용했는가?

**장점**:
- O(1) 시간 복잡도 (Redis도 O(1)이지만 네트워크 비용 없음)
- Thread-safe (ConcurrentHashMap)
- 간단한 구현

**단점**:
- Pod 재시작 시 대기 큐 데이터 손실
- 여러 Pod 간 데이터 공유 불가

**결론**: 개발 환경에서는 In-Memory로 충분하며, 프로덕션에서는 Redis로 전환 가능
