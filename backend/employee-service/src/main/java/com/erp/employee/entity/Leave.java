package com.erp.employee.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "leaves")
@Data
public class Leave {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "employee_id", nullable = false)
    private Long employeeId;
    
    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;
    
    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;
    
    @Column(name = "days", nullable = false)
    private Integer days;
    
    @Column(name = "reason")
    private String reason;
    
    @Column(name = "status")
    private String status = "PENDING"; // PENDING, APPROVED, REJECTED
    
    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();
}
