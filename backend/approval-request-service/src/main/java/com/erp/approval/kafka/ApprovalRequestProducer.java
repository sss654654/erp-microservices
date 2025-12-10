package com.erp.approval.kafka;

import com.erp.approval.dto.ApprovalRequestMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ApprovalRequestProducer {
    
    private final KafkaTemplate<String, Object> kafkaTemplate;
    
    @Value("${kafka.topics.approval-requests:approval-requests}")
    private String topic;
    
    public void sendApprovalRequest(ApprovalRequestMessage message) {
        String key = String.valueOf(message.getRequestId());
        kafkaTemplate.send(topic, key, message).whenComplete((result, ex) -> {
            if (ex == null) {
                log.info("Sent approval request: requestId={}", message.getRequestId());
            } else {
                log.error("Failed to send approval request: requestId={}", message.getRequestId(), ex);
            }
        });
    }
}
