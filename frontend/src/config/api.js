const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost';
const WS_BASE_URL = import.meta.env.VITE_WS_BASE_URL || 'http://localhost:8084';

export const API_ENDPOINTS = {
  EMPLOYEE: `${API_BASE_URL}/api/employees`,
  ATTENDANCE: `${API_BASE_URL}/api/attendance`,
  QUEST: `${API_BASE_URL}/api/quests`,
  LEAVE: `${API_BASE_URL}/api/leaves`,
  APPROVAL_REQUEST: `${API_BASE_URL}/api/approvals`,
  APPROVAL_PROCESSING: `${API_BASE_URL}/api/process`,
  NOTIFICATION: WS_BASE_URL,
};
