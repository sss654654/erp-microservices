package com.erp.approval.grpc;

import com.erp.approval.service.ApprovalRequestService;
import com.erp.proto.ApprovalGrpc;
import com.erp.proto.ApprovalResultRequest;
import com.erp.proto.ApprovalResultResponse;
import io.grpc.stub.StreamObserver;
import net.devh.boot.grpc.server.service.GrpcService;

@GrpcService
public class ApprovalResultGrpcService extends ApprovalGrpc.ApprovalImplBase {
    
    private final ApprovalRequestService approvalRequestService;
    
    public ApprovalResultGrpcService(ApprovalRequestService approvalRequestService) {
        this.approvalRequestService = approvalRequestService;
    }
    
    @Override
    public void returnApprovalResult(ApprovalResultRequest request, StreamObserver<ApprovalResultResponse> responseObserver) {
        System.out.println("결재 결과 수신: requestId=" + request.getRequestId() + 
                         ", approverId=" + request.getApproverId() + 
                         ", status=" + request.getStatus());
        
        // 결재 결과 처리
        approvalRequestService.handleApprovalResult(
                request.getRequestId(),
                request.getStep(),
                request.getApproverId(),
                request.getStatus()
        );
        
        ApprovalResultResponse response = ApprovalResultResponse.newBuilder()
                .setStatus("processed")
                .build();
        
        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }
}
