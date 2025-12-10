package com.erp.processing.kafka;

import com.erp.processing.dto.ApprovalRequestMessage;
import com.erp.processing.service.ApprovalProcessingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ApprovalRequestConsumer {
    
    private final ApprovalProcessingService processingService;
    
    @KafkaListener(topics = "${kafka.topics.approval-requests:approval-requests}", groupId = "approval-processing-group")
    public void consumeApprovalRequest(ApprovalRequestMessage message) {
        try {
            log.info("Received approval request: requestId={}", message.getRequestId());
            processingService.addToQueue(message);
        } catch (Exception e) {
            log.error("Failed to process approval request: requestId={}", message.getRequestId(), e);
        }
    }
}
