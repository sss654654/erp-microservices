package com.erp.notification.config;

import com.amazonaws.xray.AWSXRay;
import com.amazonaws.xray.AWSXRayRecorderBuilder;
import com.amazonaws.xray.jakarta.servlet.AWSXRayServletFilter;
import jakarta.annotation.PostConstruct;
import jakarta.servlet.Filter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class XRayConfig {
    
    @PostConstruct
    public void init() {
        AWSXRayRecorderBuilder builder = AWSXRayRecorderBuilder.standard();
        AWSXRay.setGlobalRecorder(builder.build());
    }
    
    @Bean
    public Filter TracingFilter() {
        return new AWSXRayServletFilter("notification-service");
    }
}
