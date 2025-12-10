package com.erp.approval.dto;

import lombok.Data;
import java.util.List;

@Data
public class CreateApprovalRequest {
    private Integer requesterId;
    private String title;
    private String content;
    private String type; // ANNUAL_LEAVE, EXPENSE, PROJECT
    private Double leaveDays; // 연차 유형일 때만 사용
    private List<StepRequest> steps;
    
    @Data
    public static class StepRequest {
        private Integer step;
        private Integer approverId;
    }
}
