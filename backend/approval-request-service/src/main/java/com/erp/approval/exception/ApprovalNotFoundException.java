package com.erp.approval.exception;

public class ApprovalNotFoundException extends RuntimeException {
    public ApprovalNotFoundException(Integer requestId) {
        super("Approval not found: " + requestId);
    }
}
