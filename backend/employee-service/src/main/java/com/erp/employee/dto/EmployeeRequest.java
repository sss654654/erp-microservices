package com.erp.employee.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class EmployeeRequest {
    
    @NotBlank(message = "이름은 필수입니다")
    private String name;
    
    @NotBlank(message = "부서는 필수입니다")
    private String department;
    
    @NotBlank(message = "직책은 필수입니다")
    private String position;
}
