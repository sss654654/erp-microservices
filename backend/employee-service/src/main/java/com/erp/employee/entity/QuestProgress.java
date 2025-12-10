package com.erp.employee.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "quest_progress")
@Data
@NoArgsConstructor
public class QuestProgress {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "quest_id", nullable = false)
    private Long questId;
    
    @Column(name = "employee_id", nullable = false)
    private Long employeeId;
    
    @Column(length = 20)
    private String status = "IN_PROGRESS";
    
    @Column(name = "accepted_at")
    private LocalDateTime acceptedAt = LocalDateTime.now();
    
    @Column(name = "completed_at")
    private LocalDateTime completedAt;
    
    @Column(name = "approved_at")
    private LocalDateTime approvedAt;
    
    @Column(name = "claimed_at")
    private LocalDateTime claimedAt;
}
