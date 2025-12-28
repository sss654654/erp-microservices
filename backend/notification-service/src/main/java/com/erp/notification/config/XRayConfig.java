package com.erp.notification.config;

import com.amazonaws.xray.AWSXRay;
import com.amazonaws.xray.AWSXRayRecorderBuilder;
import com.amazonaws.xray.jakarta.servlet.AWSXRayServletFilter;
import jakarta.annotation.PostConstruct;
import jakarta.servlet.Filter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class XRayConfig {
    
    private static final Logger logger = LoggerFactory.getLogger(XRayConfig.class);
    
    @PostConstruct
    public void init() {
        logger.info("=== X-Ray Configuration Initializing ===");
        AWSXRayRecorderBuilder builder = AWSXRayRecorderBuilder.standard();
        AWSXRay.setGlobalRecorder(builder.build());
        logger.info("=== X-Ray Recorder Initialized Successfully ===");
    }
    
    @Bean
    public Filter TracingFilter() {
        logger.info("=== X-Ray Servlet Filter Created ===");
        return new AWSXRayServletFilter("notification-service");
    }
}
