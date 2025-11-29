package com.erp.employee.repository;

import com.erp.employee.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, Long> {
    
    // department로 조회
    List<Employee> findByDepartment(String department);
    
    // position으로 조회
    List<Employee> findByPosition(String position);
    
    // department와 position 둘 다로 조회
    List<Employee> findByDepartmentAndPosition(String department, String position);
}
