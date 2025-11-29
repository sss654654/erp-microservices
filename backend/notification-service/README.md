# Notification Service 구현 문서

## 1. 과제 요구사항 분석

### 1.1 Notification Service 요구사항 (배점: 20점)

과제 문서에서 요구하는 Notification Service의 핵심 기능:

1. **실시간 알림 전송**
   - 결재 상태 변경 시 실시간 알림
   - 클라이언트와 양방향 통신
   
2. **통신 프로토콜**
   - WebSocket (실시간 양방향 통신)
   
3. **데이터 저장소**
   - In-Memory (휘발성 저장소)
   - 연결된 클라이언트 세션 관리
   
4. **알림 메시지 형식**
   ```json
   {
     "type": "APPROVAL_STATUS_CHANGED",
     "approvalId": "674812a3f1e2c45678901234",
     "status": "APPROVED",
     "message": "결재가 승인되었습니다",
     "timestamp": "2025-11-28T14:30:00"
   }
   ```

### 1.2 WebSocket 요구사항

**엔드포인트**:
- `/ws/notifications` - WebSocket 연결

**메시지 타입**:
- CONNECT: 클라이언트 연결
- SUBSCRIBE: 특정 토픽 구독
- MESSAGE: 알림 메시지 수신
- DISCONNECT: 연결 해제

**STOMP 프로토콜**:
- `/topic/notifications` - 전체 알림 (브로드캐스트)
- `/user/queue/notifications` - 개인 알림

### 1.3 In-Memory 저장소

**저장 내용**:
- 연결된 WebSocket 세션
- 사용자별 구독 정보
- 최근 알림 히스토리 (선택)

**제약사항**:
- 재시작 시 연결 끊김
- 세션 정보 소실

### 1.4 다른 서비스와의 연동

**기본 구현 (100점)**:
- REST API로 알림 발송 요청 받음
- WebSocket으로 클라이언트에 전송

**확장 과제 (120점)**:
- Kafka Consumer로 이벤트 구독
- 결재 상태 변경 이벤트 자동 수신
- 실시간 알림 발송

### 1.5 구현 목표

1. Spring Boot로 WebSocket 서버 구현
2. STOMP 프로토콜 사용
3. In-Memory 세션 관리
4. REST API로 알림 발송 (테스트용)
5. Docker 컨테이너화

---

## 2. 기술 스택 선택 및 비교

### 2.1 WebSocket 라이브러리: Spring WebSocket

| 옵션 | 장점 | 단점 | 선택 |
|------|------|------|------|
| **Spring WebSocket** | Spring 통합, STOMP 지원 | - | |
| Socket.IO | 다양한 클라이언트 | Java 지원 약함 | |
| Raw WebSocket | 완전한 제어 | 복잡함 | |

**선택 이유**:
- Spring Boot와 seamless 통합
- STOMP 프로토콜 자동 지원
- 브로드캐스트, 개인 메시지 쉽게 구현

### 2.2 메시지 프로토콜: STOMP

| 옵션 | 장점 | 단점 | 선택 |
|------|------|------|------|
| **STOMP** | 표준 프로토콜, 간단 | - | |
| Custom Protocol | 유연함 | 구현 복잡 | |

**선택 이유**:
- Simple Text Oriented Messaging Protocol
- 토픽 기반 pub/sub 지원
- 클라이언트 라이브러리 풍부 (SockJS, stomp.js)

### 2.3 In-Memory 저장소: ConcurrentHashMap

| 옵션 | 장점 | 단점 | 선택 |
|------|------|------|------|
| **ConcurrentHashMap** | Thread-safe, 빠름 | 휘발성 | |
| Redis | 영속성, 분산 | 비용 증가 | (확장 시 고려) |

**선택 이유**:
- 세션 관리는 휘발성이어도 무방
- 재연결 시 다시 구독하면 됨

### 2.4 최종 기술 스택

```
Language:   Java 17
Framework:  Spring Boot 3.3.13
WebSocket:  Spring WebSocket + STOMP
Storage:    ConcurrentHashMap (In-Memory)
Build:      Maven 3.9
Container:  Docker
```

---

## 3. 프로젝트 구조

```
notification-service/
├── src/main/java/com/erp/notification/
│   ├── config/
│   │   └── WebSocketConfig.java           # WebSocket 설정
│   ├── controller/
│   │   └── NotificationController.java    # REST API (테스트용)
│   ├── service/
│   │   └── NotificationService.java       # 알림 발송 로직
│   ├── model/
│   │   └── NotificationMessage.java       # 알림 메시지 모델
│   ├── storage/
│   │   └── SessionStorage.java            # 세션 관리
│   └── NotificationApplication.java
├── src/main/resources/
│   └── application.yml
├── pom.xml
└── Dockerfile
```

---

## 4. 구현 내용

### 4.1 WebSocket 설정

**WebSocketConfig.java**

```java
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    
    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // 메시지 브로커 설정
        config.enableSimpleBroker("/topic", "/queue");
        config.setApplicationDestinationPrefixes("/app");
    }
    
    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // WebSocket 엔드포인트 등록
        registry.addEndpoint("/ws/notifications")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }
}
```

**설정 설명**:
- `/topic/*`: 브로드캐스트 (모든 구독자에게 전송)
- `/queue/*`: 개인 메시지 (특정 사용자에게만 전송)
- `/app/*`: 클라이언트가 서버로 메시지 전송 시 prefix
- SockJS: WebSocket 미지원 브라우저 대응

### 4.2 알림 메시지 모델

**NotificationMessage.java**

```java
@Data
@Builder
public class NotificationMessage {
    private String type;        // APPROVAL_STATUS_CHANGED
    private String approvalId;
    private String status;      // APPROVED, REJECTED
    private String message;
    private LocalDateTime timestamp;
}
```

### 4.3 알림 발송 서비스

**NotificationService.java**

```java
@Service
@RequiredArgsConstructor
public class NotificationService {
    
    private final SimpMessagingTemplate messagingTemplate;
    
    // 전체 브로드캐스트
    public void sendToAll(NotificationMessage message) {
        messagingTemplate.convertAndSend("/topic/notifications", message);
    }
    
    // 특정 사용자에게 전송
    public void sendToUser(String userId, NotificationMessage message) {
        messagingTemplate.convertAndSendToUser(
            userId, 
            "/queue/notifications", 
            message
        );
    }
}
```

**SimpMessagingTemplate**:
- Spring이 제공하는 메시지 전송 템플릿
- WebSocket 세션 관리 자동화
- 토픽/큐 기반 메시지 라우팅

### 4.4 REST API (테스트용)

**NotificationController.java**

```java
@RestController
@RequestMapping("/notifications")
public class NotificationController {
    
    @PostMapping("/send")
    public ResponseEntity<String> sendNotification(
        @RequestBody NotificationRequest request) {
        
        NotificationMessage message = NotificationMessage.builder()
            .type("APPROVAL_STATUS_CHANGED")
            .approvalId(request.getApprovalId())
            .status(request.getStatus())
            .message(request.getMessage())
            .timestamp(LocalDateTime.now())
            .build();
        
        notificationService.sendToAll(message);
        
        return ResponseEntity.ok("Notification sent");
    }
}
```

**용도**:
- 테스트용 REST API
- Postman으로 알림 발송 테스트
- 확장 과제에서는 Kafka Consumer로 대체

### 4.5 WebSocket 이벤트 리스너

**WebSocketEventListener.java**

```java
@Component
@RequiredArgsConstructor
public class WebSocketEventListener {
    
    @EventListener
    public void handleWebSocketConnectListener(SessionConnectedEvent event) {
        log.info("New WebSocket connection");
    }
    
    @EventListener
    public void handleWebSocketDisconnectListener(SessionDisconnectEvent event) {
        log.info("WebSocket connection closed");
    }
}
```

**이벤트 처리**:
- 연결/해제 로깅
- 세션 관리 (필요 시)

---

## 5. 설정 파일

### 5.1 application.yml

```yaml
spring:
  application:
    name: notification-service

server:
  port: 8084

logging:
  level:
    com.erp.notification: DEBUG
    org.springframework.web.socket: DEBUG
```

---

## 6. 클라이언트 연결 예시

### 6.1 JavaScript (SockJS + STOMP)

```javascript
// 1. SockJS + STOMP 라이브러리 로드
<script src="https://cdn.jsdelivr.net/npm/sockjs-client@1/dist/sockjs.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@stomp/stompjs@7/bundles/stomp.umd.min.js"></script>

// 2. WebSocket 연결
const socket = new SockJS('http://localhost:8084/ws/notifications');
const stompClient = Stomp.over(socket);

// 3. 연결 및 구독
stompClient.connect({}, function(frame) {
    console.log('Connected: ' + frame);
    
    // 전체 알림 구독
    stompClient.subscribe('/topic/notifications', function(message) {
        const notification = JSON.parse(message.body);
        console.log('Received:', notification);
        showNotification(notification);
    });
});

// 4. 알림 표시
function showNotification(notification) {
    alert(`${notification.message} (${notification.status})`);
}
```

### 6.2 Postman으로 테스트

**1단계: WebSocket 연결**
- URL: `ws://localhost:8084/ws/notifications`
- Protocol: SockJS

**2단계: SUBSCRIBE**
```
SUBSCRIBE
destination:/topic/notifications
id:sub-0

```

**3단계: REST API로 알림 발송**
```bash
curl -X POST http://localhost:8084/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "approvalId": "test123",
    "status": "APPROVED",
    "message": "결재가 승인되었습니다"
  }'
```

**4단계: WebSocket에서 메시지 수신 확인**

---

## 7. 실행 방법

### 7.1 로컬 실행

```bash
cd notification-service
mvn spring-boot:run
```

**확인**:
```bash
# WebSocket 서버 실행 확인
curl http://localhost:8084/actuator/health
```

### 7.2 Docker로 실행

```bash
docker build -t notification-service:1.0 .

docker run -d \
  --name notification-service \
  -p 8084:8084 \
  notification-service:1.0
```

---

## 8. 학습 내용 정리

### 8.1 WebSocket vs HTTP

| 항목 | HTTP | WebSocket |
|------|------|-----------|
| 통신 방식 | 단방향 (요청-응답) | 양방향 (Full-duplex) |
| 연결 | 매번 새로 연결 | 지속적 연결 |
| 오버헤드 | 높음 (헤더 반복) | 낮음 (한 번만 핸드셰이크) |
| 실시간성 | 폴링 필요 | 즉시 전송 |
| 사용 사례 | REST API | 채팅, 알림, 실시간 데이터 |

### 8.2 STOMP 프로토콜

**장점**:
- 텍스트 기반 프로토콜 (디버깅 쉬움)
- Pub/Sub 패턴 지원
- 다양한 클라이언트 라이브러리

**메시지 형식**:
```
COMMAND
header1:value1
header2:value2

Body^@
```

### 8.3 브로드캐스트 vs 개인 메시지

| 타입 | 경로 | 용도 | 예시 |
|------|------|------|------|
| 브로드캐스트 | /topic/* | 모든 구독자 | 공지사항 |
| 개인 메시지 | /queue/* | 특정 사용자 | 개인 알림 |

### 8.4 확장 과제 (Kafka 통합)

**현재 (기본 구현)**:
```
REST API --> Notification Service --> WebSocket
```

**확장 (Kafka)**:
```
Approval Service --> Kafka --> Notification Service --> WebSocket
```

**개선점**:
- 서비스 간 결합도 감소
- 이벤트 기반 아키텍처
- 알림 발송 자동화

---

## 9. 다음 단계

Notification Service는 다음과 연동된다:

**Approval Request Service**:
- 결재 상태 변경 시 알림 발송 (REST API 호출)

**Kafka (확장 과제)**:
- 결재 이벤트 구독
- 자동 알림 발송

---

## 10. 참고 자료

- Spring WebSocket: https://spring.io/guides/gs/messaging-stomp-websocket/
- STOMP Protocol: https://stomp.github.io/
- SockJS: https://github.com/sockjs/sockjs-client
- Stomp.js: https://github.com/stomp-js/stompjs
