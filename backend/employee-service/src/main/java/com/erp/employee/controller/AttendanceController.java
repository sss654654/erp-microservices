package com.erp.employee.controller;

import com.erp.employee.entity.Attendance;
import com.erp.employee.entity.Employee;
import com.erp.employee.repository.AttendanceRepository;
import com.erp.employee.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/attendance")
@RequiredArgsConstructor
public class AttendanceController {
    
    private final AttendanceRepository repository;
    private final EmployeeRepository employeeRepository;
    
    @PostMapping("/check-in/{employeeId}")
    public ResponseEntity<?> checkIn(@PathVariable Long employeeId) {
        Employee employee = employeeRepository.findById(employeeId)
            .orElseThrow(() -> new RuntimeException("Employee not found"));
        
        // 출석 기록
        Attendance attendance = new Attendance();
        attendance.setEmployeeId(employeeId);
        attendance.setCheckInTime(LocalDateTime.now());
        attendance.setStatus("COMPLETED");
        repository.save(attendance);
        
        // 출석 카운트 증가
        employee.setAttendanceCount(employee.getAttendanceCount() + 1);
        
        // 30일마다 연차 1일 지급
        boolean rewardEarned = false;
        if (employee.getAttendanceCount() % 30 == 0) {
            employee.setAnnualLeaveBalance(employee.getAnnualLeaveBalance() + 1.0);
            rewardEarned = true;
        }
        
        employeeRepository.save(employee);
        
        int progress = (employee.getAttendanceCount() % 30) * 100 / 30;
        
        return ResponseEntity.ok(Map.of(
            "attendanceCount", employee.getAttendanceCount(),
            "questProgress", progress,
            "rewardEarned", rewardEarned,
            "currentLeaveBalance", employee.getAnnualLeaveBalance()
        ));
    }
    
    @GetMapping("/history/{employeeId}")
    public ResponseEntity<List<Attendance>> getHistory(@PathVariable Long employeeId) {
        return ResponseEntity.ok(repository.findByEmployeeIdOrderByCheckInTimeDesc(employeeId));
    }
    
    @GetMapping("/progress/{employeeId}")
    public ResponseEntity<?> getProgress(@PathVariable Long employeeId) {
        Employee employee = employeeRepository.findById(employeeId)
            .orElseThrow(() -> new RuntimeException("Employee not found"));
        
        int currentCount = employee.getAttendanceCount() % 30;
        int progress = currentCount * 100 / 30;
        
        return ResponseEntity.ok(Map.of(
            "attendanceCount", currentCount,
            "targetCount", 30,
            "progress", progress,
            "nextRewardAt", 30 - currentCount
        ));
    }
}
