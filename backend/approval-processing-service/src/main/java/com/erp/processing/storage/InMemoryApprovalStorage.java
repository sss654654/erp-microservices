package com.erp.processing.storage;

import com.erp.proto.ApprovalRequest;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class InMemoryApprovalStorage {
    
    // Key: approverId, Value: 해당 결재자의 대기 목록
    private final Map<Integer, List<ApprovalRequest>> approverQueue = new ConcurrentHashMap<>();
    
    public void addToQueue(Integer approverId, ApprovalRequest request) {
        approverQueue.computeIfAbsent(approverId, k -> Collections.synchronizedList(new ArrayList<>()))
                     .add(request);
    }
    
    public List<ApprovalRequest> getQueue(Integer approverId) {
        return approverQueue.getOrDefault(approverId, Collections.emptyList());
    }
    
    public Optional<ApprovalRequest> findRequest(Integer approverId, Integer requestId) {
        List<ApprovalRequest> queue = approverQueue.get(approverId);
        if (queue == null) return Optional.empty();
        
        return queue.stream()
                    .filter(req -> req.getRequestId() == requestId)
                    .findFirst();
    }
    
    public boolean removeFromQueue(Integer approverId, Integer requestId) {
        List<ApprovalRequest> queue = approverQueue.get(approverId);
        if (queue == null) return false;
        
        return queue.removeIf(req -> req.getRequestId() == requestId);
    }
}
