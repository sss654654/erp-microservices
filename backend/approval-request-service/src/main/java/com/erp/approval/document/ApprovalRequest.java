package com.erp.approval.document;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Document(collection = "approval_requests")
public class ApprovalRequest {
    
    @Id
    private String id;
    
    private Integer requestId;
    private Integer requesterId;
    private String title;
    private String content;
    private List<ApprovalStep> steps;
    private String finalStatus; // in_progress, approved, rejected
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    
    @Data
    public static class ApprovalStep {
        private Integer step;
        private Integer approverId;
        private String status; // pending, approved, rejected
        private LocalDateTime updatedAt;
    }
}
