import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';

const approvalRequestAPI = axios.create({
  baseURL: API_ENDPOINTS.APPROVAL_REQUEST,
});

export const approvalService = {
  createApproval: (data) => approvalRequestAPI.post('', data),
  getApprovals: () => approvalRequestAPI.get(''),
  getApproval: (requestId) => approvalRequestAPI.get(`/${requestId}`),
};
