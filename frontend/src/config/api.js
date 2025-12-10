const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost';

export const API_ENDPOINTS = {
  EMPLOYEE: `${API_BASE_URL}/api/employees`,
  APPROVAL_REQUEST: `${API_BASE_URL}/api/approvals`,
  APPROVAL_PROCESSING: `${API_BASE_URL}/api/process`,
  NOTIFICATION: `${API_BASE_URL}/api/notifications`,
};
