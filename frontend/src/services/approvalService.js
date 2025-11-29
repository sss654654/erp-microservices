import axios from 'axios';

const approvalRequestAPI = axios.create({
  baseURL: 'http://localhost:8082',
});

export const approvalService = {
  // 결재 요청 생성
  createApproval: (data) => approvalRequestAPI.post('/approvals', data),
  
  // 전체 결재 목록 조회
  getApprovals: () => approvalRequestAPI.get('/approvals'),
};
