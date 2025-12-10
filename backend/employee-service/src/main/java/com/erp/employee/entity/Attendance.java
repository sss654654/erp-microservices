package com.erp.employee.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Entity
@Table(name = "attendance")
@Data
public class Attendance {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "employee_id", nullable = false)
    private Long employeeId;
    
    @Column(name = "check_in_time", nullable = false)
    private LocalDateTime checkInTime;
    
    @Column(name = "check_out_time")
    private LocalDateTime checkOutTime;
    
    @Column(name = "work_hours")
    private Double workHours;
    
    @Column(name = "status")
    private String status = "IN_PROGRESS"; // IN_PROGRESS, COMPLETED
    
    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();
}
