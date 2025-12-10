package com.erp.approval.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ApprovalResultMessage {
    private Integer requestId;
    private Integer step;
    private Integer approverId;
    private String status;
    private LocalDateTime timestamp;
}
