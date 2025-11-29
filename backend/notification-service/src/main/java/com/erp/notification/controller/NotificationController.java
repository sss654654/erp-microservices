package com.erp.notification.controller;

import com.erp.notification.model.NotificationMessage;
import com.erp.notification.model.NotificationRequest;
import com.erp.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

@Slf4j
@RestController
@RequestMapping("/notifications")
@RequiredArgsConstructor
public class NotificationController {
    
    private final NotificationService notificationService;
    
    /**
     * 알림 발송 (테스트용 REST API)
     * 실제로는 Kafka Consumer로 대체 예정
     */
    @PostMapping("/send")
    public ResponseEntity<String> sendNotification(@RequestBody NotificationRequest request) {
        log.info("POST /notifications/send: {}", request);
        
        NotificationMessage message = NotificationMessage.builder()
                .type("APPROVAL_STATUS_CHANGED")
                .approvalId(request.getApprovalId())
                .status(request.getStatus())
                .message(request.getMessage())
                .timestamp(LocalDateTime.now())
                .build();
        
        notificationService.sendToAll(message);
        
        return ResponseEntity.ok("Notification sent successfully");
    }
    
    /**
     * 특정 사용자에게 알림 발송
     */
    @PostMapping("/send/{userId}")
    public ResponseEntity<String> sendToUser(
            @PathVariable String userId,
            @RequestBody NotificationRequest request) {
        log.info("POST /notifications/send/{}: {}", userId, request);
        
        NotificationMessage message = NotificationMessage.builder()
                .type("APPROVAL_STATUS_CHANGED")
                .approvalId(request.getApprovalId())
                .status(request.getStatus())
                .message(request.getMessage())
                .timestamp(LocalDateTime.now())
                .build();
        
        notificationService.sendToUser(userId, message);
        
        return ResponseEntity.ok("Notification sent to user: " + userId);
    }
    
    /**
     * Health Check
     */
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Notification Service is running");
    }
}
