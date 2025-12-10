package com.erp.employee.service;

import com.erp.employee.dto.EmployeeRequest;
import com.erp.employee.dto.EmployeeUpdateRequest;
import com.erp.employee.entity.Employee;
import com.erp.employee.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class EmployeeService {
    
    private final EmployeeRepository employeeRepository;
    
    // 직원 생성
    @Transactional
    public Employee createEmployee(EmployeeRequest request) {
        Employee employee = new Employee(
            request.getName(),
            request.getDepartment(),
            request.getPosition()
        );
        return employeeRepository.save(employee);
    }
    
    // 전체 조회
    @Transactional(readOnly = true)
    public List<Employee> getAllEmployees() {
        return employeeRepository.findAll();
    }
    
    // 필터링 조회
    @Transactional(readOnly = true)
    public List<Employee> getEmployees(String department, String position) {
        if (department != null && position != null) {
            return employeeRepository.findByDepartmentAndPosition(department, position);
        } else if (department != null) {
            return employeeRepository.findByDepartment(department);
        } else if (position != null) {
            return employeeRepository.findByPosition(position);
        } else {
            return employeeRepository.findAll();
        }
    }
    
    // ID로 조회
    @Transactional(readOnly = true)
    public Employee getEmployeeById(Long id) {
        return employeeRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("직원을 찾을 수 없습니다: " + id));
    }
    
    // 수정 (department, position만)
    @Transactional
    public Employee updateEmployee(Long id, EmployeeUpdateRequest request) {
        Employee employee = getEmployeeById(id);
        
        // department와 position만 수정
        if (request.getDepartment() != null) {
            employee.setDepartment(request.getDepartment());
        }
        if (request.getPosition() != null) {
            employee.setPosition(request.getPosition());
        }
        
        return employeeRepository.save(employee);
    }
    
    // 삭제
    @Transactional
    public void deleteEmployee(Long id) {
        if (!employeeRepository.existsById(id)) {
            throw new RuntimeException("직원을 찾을 수 없습니다: " + id);
        }
        employeeRepository.deleteById(id);
    }
}
