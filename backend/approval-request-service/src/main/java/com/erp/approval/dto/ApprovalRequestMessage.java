package com.erp.approval.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ApprovalRequestMessage {
    private Integer requestId;
    private Integer requesterId;
    private String title;
    private String content;
    private List<StepDto> steps;
    private LocalDateTime timestamp;
    
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class StepDto {
        private Integer step;
        private Integer approverId;
        private String status;
    }
}
