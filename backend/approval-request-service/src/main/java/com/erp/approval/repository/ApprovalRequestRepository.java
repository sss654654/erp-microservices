package com.erp.approval.repository;

import com.erp.approval.document.ApprovalRequest;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.Optional;

public interface ApprovalRequestRepository extends MongoRepository<ApprovalRequest, String> {
    Optional<ApprovalRequest> findByRequestId(Integer requestId);
}
