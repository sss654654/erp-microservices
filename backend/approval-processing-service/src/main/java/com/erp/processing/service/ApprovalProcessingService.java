package com.erp.processing.service;

import com.erp.processing.dto.ApprovalRequestMessage;
import com.erp.processing.dto.ApprovalResultMessage;
import com.erp.processing.kafka.ApprovalResultProducer;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ApprovalProcessingService {
    
    private final ApprovalResultProducer resultProducer;
    private final Map<Integer, List<ApprovalRequestMessage>> approverQueue = new ConcurrentHashMap<>();
    
    public void addToQueue(ApprovalRequestMessage message) {
        // 첫 번째 pending 단계 찾기
        Optional<ApprovalRequestMessage.StepDto> firstPending = message.getSteps().stream()
            .filter(s -> "pending".equals(s.getStatus()))
            .findFirst();
        
        if (firstPending.isPresent()) {
            Integer approverId = firstPending.get().getApproverId();
            approverQueue.computeIfAbsent(approverId, k -> new CopyOnWriteArrayList<>()).add(message);
            log.info("Added to queue: approverId={}, requestId={}", approverId, message.getRequestId());
        }
    }
    
    public List<Map<String, Object>> getQueue(Integer approverId) {
        return approverQueue.getOrDefault(approverId, List.of()).stream()
            .map(req -> Map.of(
                "requestId", (Object) req.getRequestId(),
                "requesterId", req.getRequesterId(),
                "title", req.getTitle(),
                "content", req.getContent(),
                "steps", req.getSteps().stream()
                    .map(step -> Map.of(
                        "step", (Object) step.getStep(),
                        "approverId", step.getApproverId(),
                        "status", step.getStatus()
                    ))
                    .collect(Collectors.toList())
            ))
            .collect(Collectors.toList());
    }
    
    public boolean processApproval(Integer approverId, Integer requestId, String status) {
        List<ApprovalRequestMessage> queue = approverQueue.get(approverId);
        if (queue == null) {
            return false;
        }
        
        Optional<ApprovalRequestMessage> requestOpt = queue.stream()
            .filter(r -> r.getRequestId().equals(requestId))
            .findFirst();
        
        if (requestOpt.isEmpty()) {
            return false;
        }
        
        ApprovalRequestMessage request = requestOpt.get();
        
        // 현재 결재 단계 찾기
        Optional<ApprovalRequestMessage.StepDto> currentStepOpt = request.getSteps().stream()
            .filter(step -> step.getApproverId().equals(approverId) && "pending".equals(step.getStatus()))
            .findFirst();
        
        if (currentStepOpt.isEmpty()) {
            return false;
        }
        
        ApprovalRequestMessage.StepDto currentStep = currentStepOpt.get();
        
        // 대기 목록에서 제거
        queue.remove(request);
        
        // Kafka로 결과 전송
        ApprovalResultMessage resultMessage = new ApprovalResultMessage(
            requestId,
            currentStep.getStep(),
            approverId,
            status,
            LocalDateTime.now()
        );
        resultProducer.sendApprovalResult(resultMessage);
        
        return true;
    }
}
