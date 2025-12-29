package com.erp.approval.service;

import com.erp.approval.document.ApprovalRequest;
import com.erp.approval.dto.ApprovalRequestMessage;
import com.erp.approval.dto.CreateApprovalRequest;
import com.erp.approval.exception.ApprovalNotFoundException;
import com.erp.approval.exception.InvalidStepsException;
import com.erp.approval.kafka.ApprovalRequestProducer;
import com.erp.approval.repository.ApprovalRequestRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class ApprovalRequestService {
    
    private final ApprovalRequestRepository repository;
    private final EmployeeClient employeeClient;
    private final ApprovalRequestProducer approvalRequestProducer;
    private final RestTemplate restTemplate;
    private final SequenceGeneratorService sequenceGenerator;
    
    @Value("${notification.service.url}")
    private String notificationServiceUrl;
    
    public ApprovalRequestService(ApprovalRequestRepository repository,
                                  EmployeeClient employeeClient,
                                  ApprovalRequestProducer approvalRequestProducer,
                                  RestTemplate restTemplate,
                                  SequenceGeneratorService sequenceGenerator) {
        this.repository = repository;
        this.employeeClient = employeeClient;
        this.approvalRequestProducer = approvalRequestProducer;
        this.restTemplate = restTemplate;
        this.sequenceGenerator = sequenceGenerator;
    }
    
    public ApprovalRequest createApproval(CreateApprovalRequest request) {
        // requesterId null 체크
        if (request.getRequesterId() == null) {
            throw new IllegalArgumentException("requesterId is required");
        }
        
        // 1. 직원 검증
        employeeClient.validateEmployee(request.getRequesterId().longValue());
        for (CreateApprovalRequest.StepRequest step : request.getSteps()) {
            employeeClient.validateEmployee(step.getApproverId().longValue());
        }
        
        // 2. steps가 1부터 오름차순인지 검증
        List<Integer> stepNumbers = request.getSteps().stream()
                .map(CreateApprovalRequest.StepRequest::getStep)
                .sorted()
                .collect(Collectors.toList());
        
        for (int i = 0; i < stepNumbers.size(); i++) {
            if (stepNumbers.get(i) != i + 1) {
                throw new InvalidStepsException("Steps must be sequential starting from 1");
            }
        }
        
        // 3. MongoDB에 저장
        ApprovalRequest approval = new ApprovalRequest();
        approval.setRequestId(sequenceGenerator.generateSequence("approval_request_seq"));
        approval.setRequesterId(request.getRequesterId());
        approval.setTitle(request.getTitle());
        approval.setContent(request.getContent());
        approval.setType(request.getType());
        approval.setLeaveDays(request.getLeaveDays());
        
        List<ApprovalRequest.ApprovalStep> steps = request.getSteps().stream()
                .map(step -> {
                    ApprovalRequest.ApprovalStep approvalStep = new ApprovalRequest.ApprovalStep();
                    approvalStep.setStep(step.getStep());
                    approvalStep.setApproverId(step.getApproverId());
                    approvalStep.setStatus("pending");
                    return approvalStep;
                })
                .collect(Collectors.toList());
        
        approval.setSteps(steps);
        approval.setFinalStatus("in_progress");
        approval.setCreatedAt(LocalDateTime.now());
        
        ApprovalRequest saved = repository.save(approval);
        
        // 4. Kafka로 Processing Service에 전달
        ApprovalRequestMessage message = new ApprovalRequestMessage(
            saved.getRequestId(),
            saved.getRequesterId(),
            saved.getTitle(),
            saved.getContent(),
            saved.getSteps().stream()
                .map(s -> new ApprovalRequestMessage.StepDto(s.getStep(), s.getApproverId(), s.getStatus()))
                .collect(Collectors.toList()),
            LocalDateTime.now()
        );
        approvalRequestProducer.sendApprovalRequest(message);
        
        return saved;
    }
    
    public void handleApprovalResult(Integer requestId, Integer step, Integer approverId, String status) {
        ApprovalRequest approval = repository.findByRequestId(requestId)
                .orElseThrow(() -> new ApprovalNotFoundException(requestId));
        
        // 해당 단계 업데이트
        approval.getSteps().stream()
                .filter(s -> s.getStep().equals(step) && s.getApproverId().equals(approverId))
                .findFirst()
                .ifPresent(s -> {
                    s.setStatus(status);
                    s.setUpdatedAt(LocalDateTime.now());
                });
        
        approval.setUpdatedAt(LocalDateTime.now());
        
        if ("rejected".equals(status)) {
            // 반려 처리
            approval.setFinalStatus("rejected");
            repository.save(approval);
            
            // Notification Service 호출
            sendNotification(approval.getRequesterId(), requestId, "rejected", approverId);
            
        } else if ("approved".equals(status)) {
            // 다음 pending 단계 확인
            boolean hasNextPending = approval.getSteps().stream()
                    .anyMatch(s -> "pending".equals(s.getStatus()));
            
            if (hasNextPending) {
                // 다음 단계로 진행
                repository.save(approval);
                ApprovalRequestMessage message = new ApprovalRequestMessage(
                    approval.getRequestId(),
                    approval.getRequesterId(),
                    approval.getTitle(),
                    approval.getContent(),
                    approval.getSteps().stream()
                        .map(s -> new ApprovalRequestMessage.StepDto(s.getStep(), s.getApproverId(), s.getStatus()))
                        .collect(Collectors.toList()),
                    LocalDateTime.now()
                );
                approvalRequestProducer.sendApprovalRequest(message);
            } else {
                // 모든 단계 완료
                approval.setFinalStatus("approved");
                repository.save(approval);
                
                // Notification Service 호출
                sendNotification(approval.getRequesterId(), requestId, "approved", null);
            }
        }
    }
    
    private void sendNotification(Integer employeeId, Integer requestId, String result, Integer rejectedBy) {
        try {
            String url = notificationServiceUrl + "/notifications/send";
            Map<String, Object> notification = new HashMap<>();
            notification.put("requestId", requestId);
            notification.put("status", result);
            notification.put("message", "approved".equals(result) ? "결재가 승인되었습니다" : "결재가 반려되었습니다");
            if (rejectedBy != null) {
                notification.put("rejectedBy", rejectedBy);
            }
            restTemplate.postForEntity(url, notification, String.class);
        } catch (Exception e) {
            System.err.println("알림 전송 실패: " + e.getMessage());
        }
    }
    
    public List<ApprovalRequest> getAllApprovals() {
        return repository.findAll();
    }
    
    public ApprovalRequest getApprovalById(Integer requestId) {
        return repository.findByRequestId(requestId)
                .orElseThrow(() -> new ApprovalNotFoundException(requestId));
    }
    
    public List<ApprovalRequest> getPendingApprovalsByApproverId(Integer approverId) {
        return repository.findAll().stream()
                .filter(approval -> approval.getSteps().stream()
                        .anyMatch(step -> step.getApproverId().equals(approverId) && "pending".equals(step.getStatus())))
                .collect(Collectors.toList());
    }
    
    public void deleteAll() {
        repository.deleteAll();
    }
    
    public void approveRequest(Integer requestId, Integer approverId) {
        ApprovalRequest approval = repository.findByRequestId(requestId)
                .orElseThrow(() -> new ApprovalNotFoundException(requestId));
        
        // 현재 승인자의 단계 찾기
        ApprovalRequest.ApprovalStep currentStep = approval.getSteps().stream()
                .filter(s -> s.getApproverId().equals(approverId) && "pending".equals(s.getStatus()))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("승인 권한이 없습니다"));
        
        currentStep.setStatus("approved");
        currentStep.setUpdatedAt(LocalDateTime.now());
        
        // 다음 pending 단계 확인
        boolean hasNextPending = approval.getSteps().stream()
                .anyMatch(s -> "pending".equals(s.getStatus()));
        
        if (!hasNextPending) {
            // 모든 단계 완료 - 연차 차감
            approval.setFinalStatus("approved");
            
            if ("ANNUAL_LEAVE".equals(approval.getType()) && approval.getLeaveDays() != null) {
                // Employee Service에 연차 차감 요청
                try {
                    String url = "http://employee-service.erp-dev.svc.cluster.local:8081/employees/" 
                                + approval.getRequesterId() + "/deduct-leave";
                    Map<String, Double> body = Map.of("days", approval.getLeaveDays());
                    restTemplate.postForEntity(url, body, String.class);
                } catch (Exception e) {
                    System.err.println("연차 차감 실패: " + e.getMessage());
                }
            }
        }
        
        approval.setUpdatedAt(LocalDateTime.now());
        repository.save(approval);
    }
    
    public void rejectRequest(Integer requestId, Integer approverId) {
        ApprovalRequest approval = repository.findByRequestId(requestId)
                .orElseThrow(() -> new ApprovalNotFoundException(requestId));
        
        // 현재 승인자의 단계 찾기
        ApprovalRequest.ApprovalStep currentStep = approval.getSteps().stream()
                .filter(s -> s.getApproverId().equals(approverId) && "pending".equals(s.getStatus()))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("반려 권한이 없습니다"));
        
        currentStep.setStatus("rejected");
        currentStep.setUpdatedAt(LocalDateTime.now());
        
        approval.setFinalStatus("rejected");
        approval.setUpdatedAt(LocalDateTime.now());
        repository.save(approval);
    }
}
