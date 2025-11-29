package com.erp.processing.grpc;

import com.erp.proto.ApprovalGrpc;
import com.erp.proto.ApprovalResultRequest;
import com.erp.proto.ApprovalResultResponse;
import net.devh.boot.grpc.client.inject.GrpcClient;
import org.springframework.stereotype.Service;

@Service
public class ApprovalResultClient {
    
    @GrpcClient("approvalrequestservice")
    private ApprovalGrpc.ApprovalBlockingStub approvalStub;
    
    public void sendResult(Integer requestId, Integer step, Integer approverId, String status) {
        ApprovalResultRequest request = ApprovalResultRequest.newBuilder()
                .setRequestId(requestId)
                .setStep(step)
                .setApproverId(approverId)
                .setStatus(status)
                .build();
        
        ApprovalResultResponse response = approvalStub.returnApprovalResult(request);
        System.out.println("결재 결과 전송 완료: " + response.getStatus());
    }
}
