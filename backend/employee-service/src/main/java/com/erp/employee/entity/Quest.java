package com.erp.employee.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "quests")
@Data
@NoArgsConstructor
public class Quest {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, length = 200)
    private String title;
    
    @Column(columnDefinition = "TEXT")
    private String description;
    
    @Column(name = "reward_days", nullable = false)
    private Double rewardDays;
    
    @Column(nullable = false, length = 50)
    private String department;
    
    @Column(name = "created_by", nullable = false)
    private Long createdBy;
    
    @Column(length = 20)
    private String status = "AVAILABLE";
    
    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();
}
