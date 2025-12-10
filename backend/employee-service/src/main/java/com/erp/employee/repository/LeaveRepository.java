package com.erp.employee.repository;

import com.erp.employee.entity.Leave;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface LeaveRepository extends JpaRepository<Leave, Long> {
    List<Leave> findByEmployeeIdOrderByCreatedAtDesc(Long employeeId);
}
