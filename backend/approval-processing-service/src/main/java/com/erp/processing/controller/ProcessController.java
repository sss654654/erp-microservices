package com.erp.processing.controller;

import com.erp.processing.grpc.ApprovalResultClient;
import com.erp.processing.storage.RedisApprovalStorage;
import com.erp.proto.ApprovalRequest;
import com.erp.proto.Step;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/process")
public class ProcessController {
    
    private final RedisApprovalStorage storage;
    private final ApprovalResultClient resultClient;
    
    public ProcessController(RedisApprovalStorage storage, ApprovalResultClient resultClient) {
        this.storage = storage;
        this.resultClient = resultClient;
    }
    
    @GetMapping("/{approverId}")
    public ResponseEntity<?> getApproverQueue(@PathVariable Integer approverId) {
        List<ApprovalRequest> queue = storage.getQueue(approverId);
        
        List<Map<String, Object>> result = queue.stream()
                .map(req -> Map.of(
                        "requestId", req.getRequestId(),
                        "requesterId", req.getRequesterId(),
                        "title", req.getTitle(),
                        "content", req.getContent(),
                        "steps", req.getStepsList().stream()
                                .map(step -> Map.of(
                                        "step", step.getStep(),
                                        "approverId", step.getApproverId(),
                                        "status", step.getStatus()
                                ))
                                .collect(Collectors.toList())
                ))
                .collect(Collectors.toList());
        
        return ResponseEntity.ok(result);
    }
    
    @PostMapping("/{approverId}/{requestId}")
    public ResponseEntity<?> processApproval(
            @PathVariable Integer approverId,
            @PathVariable Integer requestId,
            @RequestBody Map<String, String> body) {
        
        String status = body.get("status"); // "approved" or "rejected"
        
        if (!"approved".equals(status) && !"rejected".equals(status)) {
            return ResponseEntity.badRequest().body(Map.of("error", "status must be 'approved' or 'rejected'"));
        }
        
        Optional<ApprovalRequest> requestOpt = storage.findRequest(approverId, requestId);
        if (requestOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        
        ApprovalRequest request = requestOpt.get();
        
        // 현재 결재 단계 찾기
        Optional<Step> currentStepOpt = request.getStepsList().stream()
                .filter(step -> step.getApproverId() == approverId && "pending".equals(step.getStatus()))
                .findFirst();
        
        if (currentStepOpt.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "No pending approval for this approver"));
        }
        
        Step currentStep = currentStepOpt.get();
        
        // 대기 목록에서 제거
        storage.removeFromQueue(approverId, requestId);
        
        // gRPC로 결과 전송
        resultClient.sendResult(requestId, currentStep.getStep(), approverId, status);
        
        return ResponseEntity.ok(Map.of(
                "message", "Approval processed",
                "requestId", requestId,
                "status", status
        ));
    }
}
