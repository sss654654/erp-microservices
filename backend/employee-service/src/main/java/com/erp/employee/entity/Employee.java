package com.erp.employee.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "employees")
@Getter
@Setter
@NoArgsConstructor
public class Employee {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, length = 100)
    private String name;
    
    @Column(unique = true, length = 100)
    private String email;
    
    @Column(nullable = false, length = 100)
    private String department;
    
    @Column(nullable = false, length = 100)
    private String position;
    
    @Column(name = "annual_leave_balance")
    private Double annualLeaveBalance = 0.0;
    
    @Column(name = "attendance_count")
    private Integer attendanceCount = 0;
    
    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
    
    public Employee(String name, String department, String position) {
        this.name = name;
        this.department = department;
        this.position = position;
        this.annualLeaveBalance = 0.0;
        this.attendanceCount = 0;
    }
}
