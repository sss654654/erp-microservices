# Notification Service

실시간 알림 전송을 담당하는 마이크로서비스

## 책임

- Redis Pub/Sub로 모든 Pod에 메시지 전파
- WebSocket (SockJS + STOMP)으로 클라이언트에게 실시간 알림 전송
- 결재 승인/반려 알림

## 기술 스택

- **Framework**: Spring Boot 3.3.5
- **Database**: Redis (ElastiCache)
- **WebSocket**: SockJS + STOMP
- **Port**: 8084

## 주요 API

- `POST /notifications/send` - 알림 전송 (Redis Pub/Sub 발행)
- `GET /ws/notifications` - WebSocket 연결 엔드포인트

## Redis Pub/Sub 구조

### Publisher
```java
@Service
public class NotificationService {
    private final RedisTemplate<String, NotificationMessage> redisTemplate;
    private final ChannelTopic notificationTopic;
    
    // Redis Pub/Sub로 메시지 발행 (모든 Pod가 수신)
    public void sendToAll(NotificationMessage message) {
        redisTemplate.convertAndSend(notificationTopic.getTopic(), message);
    }
}
```

### Subscriber
```java
@Component
public class RedisMessageSubscriber implements MessageListener {
    private final NotificationService notificationService;
    
    @Override
    public void onMessage(Message message, byte[] pattern) {
        NotificationMessage notification = deserialize(message.getBody());
        // WebSocket으로 클라이언트에게 전송
        notificationService.broadcastToWebSocket(notification);
    }
}
```

## WebSocket 구성

### STOMP 설정
```java
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config.enableSimpleBroker("/topic");
        config.setApplicationDestinationPrefixes("/app");
    }
    
    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws/notifications")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }
}
```

### 메시지 전송
```java
@Service
public class NotificationService {
    private final SimpMessagingTemplate messagingTemplate;
    
    // WebSocket으로 브로드캐스트
    public void broadcastToWebSocket(NotificationMessage message) {
        messagingTemplate.convertAndSend("/topic/notifications", message);
    }
}
```

## 동작 흐름

```
Approval Processing Service (결재 승인/반려)
  ↓
POST /notifications/send
  ↓
Redis Pub/Sub (notifications 채널)
  ↓
모든 Notification Service Pod가 수신
  ↓
각 Pod가 자신에게 연결된 WebSocket 클라이언트에게 전송
  ↓
프론트엔드 (React)가 실시간 알림 수신
```

## 왜 Redis Pub/Sub를 사용했는가?

**문제**: 여러 Pod에서 WebSocket 연결 시 특정 Pod에만 알림 전송됨

**해결**: Redis Pub/Sub로 모든 Pod에 메시지 전파

**예시**:
```
사용자 A → Pod 1 (WebSocket 연결)
사용자 B → Pod 2 (WebSocket 연결)

결재 승인 알림 발생 (Pod 1에서 처리)
  ↓
Redis Pub/Sub 발행
  ↓
Pod 1, Pod 2 모두 수신
  ↓
Pod 1 → 사용자 A에게 전송
Pod 2 → 사용자 B에게 전송
```

## 메시지 구조

```json
{
  "type": "APPROVAL_RESULT",
  "approvalId": 123,
  "requesterId": 456,
  "approverId": 789,
  "status": "approved",
  "message": "결재가 승인되었습니다",
  "timestamp": "2025-12-14T10:00:00"
}
```

## 프론트엔드 연결 (React)

```javascript
import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';

const socket = new SockJS('http://localhost:8084/ws/notifications');
const stompClient = new Client({
  webSocketFactory: () => socket,
  onConnect: () => {
    stompClient.subscribe('/topic/notifications', (message) => {
      const notification = JSON.parse(message.body);
      console.log('알림 수신:', notification);
    });
  },
});
stompClient.activate();
```

## 로컬 실행

```bash
# Redis 실행 (Docker)
docker run -d -p 6379:6379 redis:7-alpine

# 애플리케이션 실행
mvn spring-boot:run
```

## 환경 변수

```yaml
SPRING_DATA_REDIS_HOST: localhost
SPRING_DATA_REDIS_PORT: 6379
```

## 성능 고려사항

- Redis Pub/Sub는 메시지 유실 가능 (구독자가 없으면 메시지 버려짐)
- 중요한 알림은 DB에 별도 저장 필요
- WebSocket 연결 수가 많으면 Pod 수 증가 필요 (HPA 설정)
