package com.erp.notification.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationMessage {
    private String type;        // APPROVAL_STATUS_CHANGED
    private String approvalId;
    private String status;      // APPROVED, REJECTED
    private String message;
    
    @Builder.Default
    private LocalDateTime timestamp = LocalDateTime.now();
}
