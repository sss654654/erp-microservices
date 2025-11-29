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
}
