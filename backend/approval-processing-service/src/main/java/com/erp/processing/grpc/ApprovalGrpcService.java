package com.erp.processing.grpc;

import com.erp.processing.storage.InMemoryApprovalStorage;
import com.erp.proto.*;
import io.grpc.stub.StreamObserver;
import net.devh.boot.grpc.server.service.GrpcService;

@GrpcService
public class ApprovalGrpcService extends ApprovalGrpc.ApprovalImplBase {
    
    private final InMemoryApprovalStorage storage;
    
    public ApprovalGrpcService(InMemoryApprovalStorage storage) {
        this.storage = storage;
    }
    
    @Override
    public void requestApproval(ApprovalRequest request, StreamObserver<ApprovalResponse> responseObserver) {
        // 첫 번째 pending 상태의 결재자를 찾음
        Integer firstApproverId = request.getStepsList().stream()
                .filter(step -> "pending".equals(step.getStatus()))
                .map(Step::getApproverId)
                .findFirst()
                .orElse(null);
        
        if (firstApproverId != null) {
            // 해당 결재자의 대기 목록에 추가
            storage.addToQueue(firstApproverId, request);
            System.out.println("결재 요청 수신: requestId=" + request.getRequestId() + 
                             ", approverId=" + firstApproverId);
        }
        
        ApprovalResponse response = ApprovalResponse.newBuilder()
                .setStatus("received")
                .build();
        
        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }
}
