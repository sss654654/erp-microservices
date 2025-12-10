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
import java.util.stream.Collectors;

@RestController
@RequestMapping("/employees")
@RequiredArgsConstructor
public class EmployeeController {
    
    private final EmployeeService employeeService;
    
    @PostMapping
    public ResponseEntity<Map<String, Long>> createEmployee(@Valid @RequestBody EmployeeRequest request) {
        Employee employee = employeeService.createEmployee(request);
        return ResponseEntity.ok(Map.of("id", employee.getId()));
    }
    
    @GetMapping
    public ResponseEntity<List<Employee>> getEmployees(
            @RequestParam(required = false) String department,
            @RequestParam(required = false) String position) {
        List<Employee> employees = employeeService.getEmployees(department, position);
        return ResponseEntity.ok(employees);
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<Employee> getEmployee(@PathVariable Long id) {
        Employee employee = employeeService.getEmployeeById(id);
        return ResponseEntity.ok(employee);
    }
    
    @PutMapping("/{id}")
    public ResponseEntity<Employee> updateEmployee(
            @PathVariable Long id,
            @RequestBody EmployeeUpdateRequest request) {
        Employee employee = employeeService.updateEmployee(id, request);
        return ResponseEntity.ok(employee);
    }
    
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEmployee(@PathVariable Long id) {
        employeeService.deleteEmployee(id);
        return ResponseEntity.noContent().build();
    }
    
    // 부장: 팀원 목록 조회
    @GetMapping("/team")
    public ResponseEntity<?> getTeamMembers(@RequestParam String department) {
        List<Employee> employees = employeeService.getEmployees(department, null);
        
        return ResponseEntity.ok(employees.stream().map(e -> Map.of(
            "id", e.getId(),
            "name", e.getName(),
            "position", e.getPosition(),
            "leaveBalance", e.getAnnualLeaveBalance()
        )).collect(Collectors.toList()));
    }
    
    // 부장: 연차 조정
    @PutMapping("/{id}/leave-balance")
    public ResponseEntity<?> adjustLeaveBalance(
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        
        Employee employee = employeeService.getEmployeeById(id);
        int adjustment = ((Number) body.get("adjustment")).intValue();
        
        employee.setAnnualLeaveBalance(employee.getAnnualLeaveBalance() + adjustment);
        employeeService.save(employee);
        
        return ResponseEntity.ok(Map.of(
            "newBalance", employee.getAnnualLeaveBalance(),
            "message", "연차 조정 완료"
        ));
    }
    
    // 연차 현황 조회
    @GetMapping("/{id}/leave-balance")
    public ResponseEntity<?> getLeaveBalance(@PathVariable Long id) {
        Employee employee = employeeService.getEmployeeById(id);
        
        return ResponseEntity.ok(Map.of(
            "totalLeave", employee.getAnnualLeaveBalance(),
            "remainingLeave", employee.getAnnualLeaveBalance()
        ));
    }
}
