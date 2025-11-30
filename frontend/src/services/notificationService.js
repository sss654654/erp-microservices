import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';
import { API_ENDPOINTS } from '../config/api';

let stompClient = null;

export const notificationService = {
  connect: (onMessageReceived) => {
    const socket = new SockJS(`${API_ENDPOINTS.NOTIFICATION}/ws/notifications`);
    stompClient = new Client({
      webSocketFactory: () => socket,
      onConnect: () => {
        console.log('WebSocket Connected');
        stompClient.subscribe('/topic/notifications', (message) => {
          const notification = JSON.parse(message.body);
          onMessageReceived(notification);
        });
      },
      onStompError: (frame) => {
        console.error('STOMP error:', frame);
      },
    });
    stompClient.activate();
  },

  disconnect: () => {
    if (stompClient) {
      stompClient.deactivate();
      console.log('WebSocket Disconnected');
    }
  },
};
