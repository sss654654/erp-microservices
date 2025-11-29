package com.erp.employee.dto;

import lombok.Getter;
import lombok.Setter;

// PUT 요청용 DTO - department와 position만 수정 가능
@Getter
@Setter
public class EmployeeUpdateRequest {
    
    private String department;
    private String position;
    
    // name, id는 수정 불가능하므로 필드에 포함하지 않음
}
