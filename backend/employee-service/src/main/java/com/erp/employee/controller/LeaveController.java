package com.erp.employee.controller;

import com.erp.employee.entity.Leave;
import com.erp.employee.repository.LeaveRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/leaves")
@RequiredArgsConstructor
public class LeaveController {
    
    private final LeaveRepository repository;
    
    @PostMapping
    public ResponseEntity<Leave> createLeave(@RequestBody Leave leave) {
        leave.setStatus("PENDING");
        return ResponseEntity.ok(repository.save(leave));
    }
    
    @GetMapping("/{employeeId}")
    public ResponseEntity<List<Leave>> getLeaves(@PathVariable Long employeeId) {
        return ResponseEntity.ok(repository.findByEmployeeIdOrderByCreatedAtDesc(employeeId));
    }
    
    @PutMapping("/{id}/approve")
    public ResponseEntity<Leave> approveLeave(@PathVariable Long id) {
        Leave leave = repository.findById(id)
            .orElseThrow(() -> new RuntimeException("Leave not found"));
        leave.setStatus("APPROVED");
        return ResponseEntity.ok(repository.save(leave));
    }
    
    @PutMapping("/{id}/reject")
    public ResponseEntity<Leave> rejectLeave(@PathVariable Long id) {
        Leave leave = repository.findById(id)
            .orElseThrow(() -> new RuntimeException("Leave not found"));
        leave.setStatus("REJECTED");
        return ResponseEntity.ok(repository.save(leave));
    }
    
    @GetMapping("/balance/{employeeId}")
    public ResponseEntity<Map<String, Object>> getBalance(@PathVariable Long employeeId) {
        List<Leave> approvedLeaves = repository.findByEmployeeIdOrderByCreatedAtDesc(employeeId).stream()
            .filter(l -> "APPROVED".equals(l.getStatus()))
            .toList();
        
        int usedDays = approvedLeaves.stream().mapToInt(Leave::getDays).sum();
        int totalDays = 15; // 기본 연차
        int remainingDays = totalDays - usedDays;
        
        return ResponseEntity.ok(Map.of(
            "totalDays", totalDays,
            "usedDays", usedDays,
            "remainingDays", remainingDays
        ));
    }
}
