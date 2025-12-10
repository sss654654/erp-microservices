package com.erp.employee.repository;

import com.erp.employee.entity.Quest;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface QuestRepository extends JpaRepository<Quest, Long> {
    List<Quest> findByDepartmentAndStatus(String department, String status);
    List<Quest> findByCreatedBy(Long createdBy);
}
