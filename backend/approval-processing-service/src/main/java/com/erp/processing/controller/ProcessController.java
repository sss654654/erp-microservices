package com.erp.processing.controller;

import com.erp.processing.service.ApprovalProcessingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/process")
@RequiredArgsConstructor
public class ProcessController {
    
    private final ApprovalProcessingService processingService;
    
    @GetMapping("/{approverId}")
    public ResponseEntity<?> getApproverQueue(@PathVariable Integer approverId) {
        return ResponseEntity.ok(processingService.getQueue(approverId));
    }
    
    @PostMapping("/{approverId}/{requestId}")
    public ResponseEntity<?> processApproval(
            @PathVariable Integer approverId,
            @PathVariable Integer requestId,
            @RequestBody Map<String, String> body) {
        
        String status = body.get("status");
        
        if (!"approved".equals(status) && !"rejected".equals(status)) {
            return ResponseEntity.badRequest().body(Map.of("error", "status must be 'approved' or 'rejected'"));
        }
        
        boolean success = processingService.processApproval(approverId, requestId, status);
        
        if (!success) {
            return ResponseEntity.notFound().build();
        }
        
        return ResponseEntity.ok(Map.of(
                "message", "Approval processed",
                "requestId", requestId,
                "status", status
        ));
    }
}
