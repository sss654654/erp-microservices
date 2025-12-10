package com.erp.processing.kafka;

import com.erp.processing.dto.ApprovalResultMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ApprovalResultProducer {
    
    private final KafkaTemplate<String, ApprovalResultMessage> kafkaTemplate;
    
    @Value("${kafka.topics.approval-results:approval-results}")
    private String topic;
    
    public void sendApprovalResult(ApprovalResultMessage message) {
        String key = String.valueOf(message.getRequestId());
        kafkaTemplate.send(topic, key, message).whenComplete((result, ex) -> {
            if (ex == null) {
                log.info("Sent approval result: requestId={}, status={}", message.getRequestId(), message.getStatus());
            } else {
                log.error("Failed to send approval result: requestId={}", message.getRequestId(), ex);
            }
        });
    }
}
