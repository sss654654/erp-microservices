package com.erp.employee.repository;

import com.erp.employee.entity.QuestProgress;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface QuestProgressRepository extends JpaRepository<QuestProgress, Long> {
    List<QuestProgress> findByEmployeeId(Long employeeId);
    Optional<QuestProgress> findByQuestIdAndEmployeeId(Long questId, Long employeeId);
    List<QuestProgress> findByQuestId(Long questId);
    List<QuestProgress> findByQuestIdAndStatus(Long questId, String status);
}
