package com.erp.approval.kafka;

import com.erp.approval.dto.ApprovalResultMessage;
import com.erp.approval.service.ApprovalRequestService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ApprovalResultConsumer {
    
    private final ApprovalRequestService requestService;
    
    @KafkaListener(topics = "${kafka.topics.approval-results:approval-results}", groupId = "approval-request-group")
    public void consumeApprovalResult(ApprovalResultMessage message) {
        try {
            log.info("Received approval result: requestId={}, status={}", message.getRequestId(), message.getStatus());
            requestService.handleApprovalResult(message.getRequestId(), message.getStep(), message.getApproverId(), message.getStatus());
        } catch (Exception e) {
            log.error("Failed to process approval result: requestId={}", message.getRequestId(), e);
        }
    }
}
