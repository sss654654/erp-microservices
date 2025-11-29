package com.erp.approval.dto;

import lombok.Data;
import java.util.List;

@Data
public class CreateApprovalRequest {
    private Integer requesterId;
    private String title;
    private String content;
    private List<StepRequest> steps;
    
    @Data
    public static class StepRequest {
        private Integer step;
        private Integer approverId;
    }
}
