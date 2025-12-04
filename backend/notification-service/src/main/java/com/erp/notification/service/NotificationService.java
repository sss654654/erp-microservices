package com.erp.notification.service;

import com.erp.notification.model.NotificationMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {
    
    private final SimpMessagingTemplate messagingTemplate;
    private final RedisTemplate<String, NotificationMessage> redisTemplate;
    private final ChannelTopic notificationTopic;
    
    /**
     * 전체 브로드캐스트
     * Redis Pub/Sub로 모든 Pod에 메시지 전파
     */
    public void sendToAll(NotificationMessage message) {
        log.info("Publishing notification to Redis: type={}, approvalId={}, status={}", 
                message.getType(), message.getApprovalId(), message.getStatus());
        
        // Redis Pub/Sub로 메시지 발행 (모든 Pod가 수신)
        redisTemplate.convertAndSend(notificationTopic.getTopic(), message);
        
        log.info("Notification published to Redis successfully");
    }
    
    /**
     * Redis에서 수신한 메시지를 WebSocket으로 전송
     */
    public void broadcastToWebSocket(NotificationMessage message) {
        log.info("Broadcasting to WebSocket clients: type={}, approvalId={}", 
                message.getType(), message.getApprovalId());
        
        messagingTemplate.convertAndSend("/topic/notifications", message);
    }
    
    /**
     * 특정 사용자에게 전송
     */
    public void sendToUser(String userId, NotificationMessage message) {
        log.info("Sending notification to user: userId={}, type={}, approvalId={}", 
                userId, message.getType(), message.getApprovalId());
        
        messagingTemplate.convertAndSendToUser(
                userId,
                "/queue/notifications",
                message
        );
        
        log.info("Notification sent to user successfully");
    }
}

