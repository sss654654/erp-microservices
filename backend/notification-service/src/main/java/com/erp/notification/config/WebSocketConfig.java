package com.erp.notification.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    
    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // 메시지 브로커 설정
        // /topic: 브로드캐스트 (모든 구독자)
        // /queue: 개인 메시지 (특정 사용자)
        config.enableSimpleBroker("/topic", "/queue");
        
        // 클라이언트가 서버로 메시지 전송 시 prefix
        config.setApplicationDestinationPrefixes("/app");
    }
    
    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // WebSocket 엔드포인트 등록
        registry.addEndpoint("/ws/notifications")
                .setAllowedOriginPatterns("*")  // CORS 설정
                .withSockJS();  // SockJS fallback 지원
    }
}
