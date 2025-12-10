import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';

const approvalProcessingAPI = axios.create({
  baseURL: API_ENDPOINTS.APPROVAL_PROCESSING,
});

export const processingService = {
  getQueue: (approverId) => approvalProcessingAPI.get(`/${approverId}`),
  processApproval: (approverId, requestId, status) => 
    approvalProcessingAPI.post(`/${approverId}/${requestId}`, { status }),
};
