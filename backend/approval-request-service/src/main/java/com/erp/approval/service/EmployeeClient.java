package com.erp.approval.service;

import com.erp.approval.dto.EmployeeResponse;
import com.erp.approval.exception.EmployeeNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

@Slf4j
@Component
@RequiredArgsConstructor
public class EmployeeClient {
    
    private final RestTemplate restTemplate;
    
    @Value("${employee.service.url}")
    private String employeeServiceUrl;
    
    public void validateEmployee(Long employeeId) {
        try {
            String url = employeeServiceUrl + "/employees/" + employeeId;
            log.debug("Validating employee: {}", url);
            
            ResponseEntity<EmployeeResponse> response = 
                restTemplate.getForEntity(url, EmployeeResponse.class);
            
            if (response.getStatusCode() != HttpStatus.OK) {
                throw new EmployeeNotFoundException(employeeId);
            }
        } catch (HttpClientErrorException.NotFound e) {
            log.warn("Employee not found: {}", employeeId);
            throw new EmployeeNotFoundException(employeeId);
        } catch (Exception e) {
            log.error("Error validating employee: {}", employeeId, e);
            throw new EmployeeNotFoundException(employeeId);
        }
    }
}
