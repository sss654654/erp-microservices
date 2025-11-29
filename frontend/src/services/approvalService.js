import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';

const approvalRequestAPI = axios.create({
  baseURL: API_ENDPOINTS.APPROVAL_REQUEST,
});

export const approvalService = {
  // 결재 요청 생성
  createApproval: (data) => approvalRequestAPI.post('/approvals', data),
  
  // 전체 결재 목록 조회
  getApprovals: () => approvalRequestAPI.get('/approvals'),
};
