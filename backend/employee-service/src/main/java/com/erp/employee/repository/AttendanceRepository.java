package com.erp.employee.repository;

import com.erp.employee.entity.Attendance;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface AttendanceRepository extends JpaRepository<Attendance, Long> {
    List<Attendance> findByEmployeeIdOrderByCheckInTimeDesc(Long employeeId);
    Optional<Attendance> findByEmployeeIdAndStatus(Long employeeId, String status);
}
