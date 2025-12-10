package com.erp.employee.controller;

import com.erp.employee.entity.Attendance;
import com.erp.employee.repository.AttendanceRepository;
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
    
    @PostMapping("/check-in/{employeeId}")
    public ResponseEntity<?> checkIn(@PathVariable Long employeeId) {
        // 이미 출근 중인지 확인
        if (repository.findByEmployeeIdAndStatus(employeeId, "IN_PROGRESS").isPresent()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Already checked in"));
        }
        
        Attendance attendance = new Attendance();
        attendance.setEmployeeId(employeeId);
        attendance.setCheckInTime(LocalDateTime.now());
        attendance.setStatus("IN_PROGRESS");
        
        return ResponseEntity.ok(repository.save(attendance));
    }
    
    @PostMapping("/check-out/{employeeId}")
    public ResponseEntity<?> checkOut(@PathVariable Long employeeId) {
        Attendance attendance = repository.findByEmployeeIdAndStatus(employeeId, "IN_PROGRESS")
            .orElseThrow(() -> new RuntimeException("Not checked in"));
        
        LocalDateTime checkOutTime = LocalDateTime.now();
        attendance.setCheckOutTime(checkOutTime);
        
        // 근무 시간 계산 (시간 단위)
        Duration duration = Duration.between(attendance.getCheckInTime(), checkOutTime);
        attendance.setWorkHours(duration.toMinutes() / 60.0);
        attendance.setStatus("COMPLETED");
        
        return ResponseEntity.ok(repository.save(attendance));
    }
    
    @GetMapping("/history/{employeeId}")
    public ResponseEntity<List<Attendance>> getHistory(@PathVariable Long employeeId) {
        return ResponseEntity.ok(repository.findByEmployeeIdOrderByCheckInTimeDesc(employeeId));
    }
}
