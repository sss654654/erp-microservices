import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';
import { API_ENDPOINTS } from '../config/api';

let stompClient = null;

export const notificationService = {
  connect: (onMessageReceived) => {
    console.log('WebSocket disabled - HTTPS/HTTP mixed content not allowed');
  },

  disconnect: () => {
    console.log('WebSocket disabled');
  },
};
