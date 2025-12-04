package com.erp.notification.listener;

import com.erp.notification.model.NotificationMessage;
import com.erp.notification.service.NotificationService;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class RedisMessageSubscriber implements MessageListener {
    
    private final NotificationService notificationService;
    private final ObjectMapper objectMapper = new ObjectMapper();
    
    @Override
    public void onMessage(Message message, byte[] pattern) {
        try {
            String messageBody = new String(message.getBody());
            log.info("Received message from Redis: {}", messageBody);
            
            NotificationMessage notification = objectMapper.readValue(messageBody, NotificationMessage.class);
            
            // WebSocket으로 브로드캐스트
            notificationService.broadcastToWebSocket(notification);
            
        } catch (Exception e) {
            log.error("Error processing Redis message", e);
        }
    }
}
