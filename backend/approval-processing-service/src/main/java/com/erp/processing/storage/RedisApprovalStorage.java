package com.erp.processing.storage;

import com.erp.proto.ApprovalRequest;
import com.google.protobuf.InvalidProtocolBufferException;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.stream.Collectors;

@Component
public class RedisApprovalStorage {
    
    private final RedisTemplate<String, byte[]> redisTemplate;
    
    public RedisApprovalStorage(RedisTemplate<String, byte[]> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }
    
    private String getQueueKey(Integer approverId) {
        return "approval:queue:" + approverId;
    }
    
    public void addToQueue(Integer approverId, ApprovalRequest request) {
        String key = getQueueKey(approverId);
        redisTemplate.opsForList().rightPush(key, request.toByteArray());
    }
    
    public List<ApprovalRequest> getQueue(Integer approverId) {
        String key = getQueueKey(approverId);
        List<byte[]> data = redisTemplate.opsForList().range(key, 0, -1);
        
        if (data == null) return Collections.emptyList();
        
        return data.stream()
                .map(bytes -> {
                    try {
                        return ApprovalRequest.parseFrom(bytes);
                    } catch (InvalidProtocolBufferException e) {
                        return null;
                    }
                })
                .filter(Objects::nonNull)
                .collect(Collectors.toList());
    }
    
    public Optional<ApprovalRequest> findRequest(Integer approverId, Integer requestId) {
        return getQueue(approverId).stream()
                .filter(req -> req.getRequestId() == requestId)
                .findFirst();
    }
    
    public boolean removeFromQueue(Integer approverId, Integer requestId) {
        String key = getQueueKey(approverId);
        List<ApprovalRequest> queue = getQueue(approverId);
        
        for (ApprovalRequest req : queue) {
            if (req.getRequestId() == requestId) {
                redisTemplate.opsForList().remove(key, 1, req.toByteArray());
                return true;
            }
        }
        return false;
    }
}
