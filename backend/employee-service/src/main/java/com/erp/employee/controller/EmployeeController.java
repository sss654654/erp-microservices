package com.erp.employee.controller;

import com.erp.employee.dto.EmployeeRequest;
import com.erp.employee.dto.EmployeeUpdateRequest;
import com.erp.employee.entity.Employee;
import com.erp.employee.service.EmployeeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/employees")
@RequiredArgsConstructor
public class EmployeeController {
    
    private final EmployeeService employeeService;
    
    // POST /employees - 직원 생성
    @PostMapping
    public ResponseEntity<Map<String, Long>> createEmployee(@Valid @RequestBody EmployeeRequest request) {
        Employee employee = employeeService.createEmployee(request);
        return ResponseEntity.ok(Map.of("id", employee.getId()));
    }
    
    // GET /employees - 직원 목록 조회 (필터링 지원)
    @GetMapping
    public ResponseEntity<List<Employee>> getEmployees(
            @RequestParam(required = false) String department,
            @RequestParam(required = false) String position) {
        List<Employee> employees = employeeService.getEmployees(department, position);
        return ResponseEntity.ok(employees);
    }
    
    // GET /employees/{id} - 직원 상세 조회
    @GetMapping("/{id}")
    public ResponseEntity<Employee> getEmployee(@PathVariable Long id) {
        Employee employee = employeeService.getEmployeeById(id);
        return ResponseEntity.ok(employee);
    }
    
    // PUT /employees/{id} - 직원 수정
    @PutMapping("/{id}")
    public ResponseEntity<Employee> updateEmployee(
            @PathVariable Long id,
            @RequestBody EmployeeUpdateRequest request) {
        Employee employee = employeeService.updateEmployee(id, request);
        return ResponseEntity.ok(employee);
    }
    
    // DELETE /employees/{id} - 직원 삭제
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEmployee(@PathVariable Long id) {
        employeeService.deleteEmployee(id);
        return ResponseEntity.noContent().build();
    }
}
