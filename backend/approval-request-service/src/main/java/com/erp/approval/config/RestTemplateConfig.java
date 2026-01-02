package com.erp.approval.config;

import com.amazonaws.xray.proxies.apache.http.HttpClientBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

@Configuration
public class RestTemplateConfig {
    
    @Bean
    public RestTemplate restTemplate() {
        RestTemplate restTemplate = new RestTemplate(
            new HttpComponentsClientHttpRequestFactory(
                HttpClientBuilder.create().build()
            )
        );
        return restTemplate;
    }
}
