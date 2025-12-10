package com.erp.approval.controller;

import com.erp.approval.document.ApprovalRequest;
import com.erp.approval.dto.CreateApprovalRequest;
import com.erp.approval.service.ApprovalRequestService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/approvals")
public class ApprovalRequestController {
    
    private final ApprovalRequestService service;
    
    public ApprovalRequestController(ApprovalRequestService service) {
        this.service = service;
    }
    
    @PostMapping
    public ResponseEntity<?> createApproval(@RequestBody CreateApprovalRequest request) {
        ApprovalRequest approval = service.createApproval(request);
        return ResponseEntity.ok(Map.of("requestId", approval.getRequestId()));
    }
    
    @GetMapping
    public ResponseEntity<List<ApprovalRequest>> getAllApprovals() {
        return ResponseEntity.ok(service.getAllApprovals());
    }
    
    @GetMapping("/{requestId}")
    public ResponseEntity<ApprovalRequest> getApprovalById(@PathVariable Integer requestId) {
        return ResponseEntity.ok(service.getApprovalById(requestId));
    }
    
    @PutMapping("/{requestId}/approve")
    public ResponseEntity<?> approveRequest(@PathVariable Integer requestId, @RequestBody Map<String, Integer> body) {
        Integer approverId = body.get("approverId");
        service.approveRequest(requestId, approverId);
        return ResponseEntity.ok(Map.of("message", "결재 승인 완료"));
    }
    
    @PutMapping("/{requestId}/reject")
    public ResponseEntity<?> rejectRequest(@PathVariable Integer requestId, @RequestBody Map<String, Integer> body) {
        Integer approverId = body.get("approverId");
        service.rejectRequest(requestId, approverId);
        return ResponseEntity.ok(Map.of("message", "결재 반려 완료"));
    }
    
    @DeleteMapping
    public ResponseEntity<?> deleteAllApprovals() {
        service.deleteAll();
        return ResponseEntity.ok(Map.of("message", "All approvals deleted"));
    }
}
