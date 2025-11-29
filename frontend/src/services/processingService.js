import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';

const approvalProcessingAPI = axios.create({
  baseURL: API_ENDPOINTS.APPROVAL_PROCESSING,
});

export const processingService = {
  // 결재 대기 목록 조회
  getQueue: (approverId) => approvalProcessingAPI.get(`/process/${approverId}`),
  
  // 결재 처리 (승인/반려)
  processApproval: (approverId, requestId, status) => 
    approvalProcessingAPI.post(`/process/${approverId}/${requestId}`, { status }),
};
