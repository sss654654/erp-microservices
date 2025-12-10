package com.erp.approval.grpc;

import com.erp.proto.*;
import net.devh.boot.grpc.client.inject.GrpcClient;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class ProcessingGrpcClient {
    
    @GrpcClient("approvalprocessingservice")
    private ApprovalGrpc.ApprovalBlockingStub approvalStub;
    
    public void requestApproval(Integer requestId, Integer requesterId, String title, String content, 
                                List<com.erp.approval.document.ApprovalRequest.ApprovalStep> steps) {
        
        List<Step> protoSteps = steps.stream()
                .map(step -> Step.newBuilder()
                        .setStep(step.getStep())
                        .setApproverId(step.getApproverId())
                        .setStatus(step.getStatus())
                        .build())
                .collect(Collectors.toList());
        
        ApprovalRequest request = ApprovalRequest.newBuilder()
                .setRequestId(requestId)
                .setRequesterId(requesterId)
                .setTitle(title)
                .setContent(content)
                .addAllSteps(protoSteps)
                .build();
        
        try {
            ApprovalResponse response = approvalStub.requestApproval(request);
            System.out.println("gRPC RequestApproval 응답: " + response.getStatus());
        } catch (io.grpc.StatusRuntimeException e) {
            System.err.println("Processing Service 연결 실패: " + e.getStatus());
            throw new RuntimeException("Processing Service 연결 실패", e);
        }
    }
}
