import axios from 'axios';
import { API_ENDPOINTS } from '../config/api';

let pollingInterval = null;

export const notificationService = {
  connect: (onMessageReceived) => {
    console.log('Using polling for notifications (WebSocket unavailable in production)');
    
    // 5초마다 알림 조회
    pollingInterval = setInterval(async () => {
      try {
        const employeeId = localStorage.getItem('employeeId');
        if (!employeeId) return;
        
        const response = await axios.get(`${API_ENDPOINTS.NOTIFICATION}/notifications/recent/${employeeId}`);
        if (response.data && response.data.length > 0) {
          response.data.forEach(notification => {
            onMessageReceived(notification);
          });
        }
      } catch (error) {
        console.error('Failed to fetch notifications:', error);
      }
    }, 5000);
  },

  disconnect: () => {
    if (pollingInterval) {
      clearInterval(pollingInterval);
      pollingInterval = null;
      console.log('Notification polling stopped');
    }
  },
};
