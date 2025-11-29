package com.erp.notification.service;

import com.erp.notification.model.NotificationMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {
    
    private final SimpMessagingTemplate messagingTemplate;
    
    /**
     * 전체 브로드캐스트
     * 모든 구독자에게 알림 전송
     */
    public void sendToAll(NotificationMessage message) {
        log.info("Broadcasting notification: type={}, approvalId={}, status={}", 
                message.getType(), message.getApprovalId(), message.getStatus());
        
        messagingTemplate.convertAndSend("/topic/notifications", message);
        
        log.info("Notification broadcasted successfully");
    }
    
    /**
     * 특정 사용자에게 전송
     * 개인 알림
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
