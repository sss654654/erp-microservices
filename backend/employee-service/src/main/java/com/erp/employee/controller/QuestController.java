package com.erp.employee.controller;

import com.erp.employee.entity.Employee;
import com.erp.employee.entity.Quest;
import com.erp.employee.entity.QuestProgress;
import com.erp.employee.repository.EmployeeRepository;
import com.erp.employee.repository.QuestProgressRepository;
import com.erp.employee.repository.QuestRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/quests")
@RequiredArgsConstructor
public class QuestController {
    
    private final QuestRepository questRepository;
    private final QuestProgressRepository progressRepository;
    private final EmployeeRepository employeeRepository;
    
    // 전체 퀘스트 목록 (progressList 포함)
    @GetMapping
    public ResponseEntity<?> getAllQuests() {
        List<Quest> quests = questRepository.findAll();
        
        return ResponseEntity.ok(quests.stream()
            .filter(q -> !"DELETED".equals(q.getStatus()))
            .map(q -> {
                List<QuestProgress> progresses = progressRepository.findByQuestId(q.getId());
                String createdByName = employeeRepository.findById(q.getCreatedBy())
                    .map(Employee::getName).orElse("Unknown");
                
                return Map.of(
                    "id", q.getId(),
                    "title", q.getTitle(),
                    "description", q.getDescription(),
                    "rewardDays", q.getRewardDays(),
                    "department", q.getDepartment(),
                    "createdBy", q.getCreatedBy(),
                    "createdByName", createdByName,
                    "status", q.getStatus(),
                    "progressList", progresses.stream().map(p -> Map.of(
                        "id", p.getId(),
                        "employeeId", p.getEmployeeId(),
                        "employeeName", employeeRepository.findById(p.getEmployeeId())
                            .map(Employee::getName).orElse("Unknown"),
                        "status", p.getStatus()
                    )).collect(Collectors.toList())
                );
            }).collect(Collectors.toList()));
    }
    
    // 사원: 가능한 업무 목록
    @GetMapping("/available")
    public ResponseEntity<?> getAvailableQuests(@RequestParam Long employeeId) {
        Employee employee = employeeRepository.findById(employeeId)
            .orElseThrow(() -> new RuntimeException("Employee not found"));
        
        List<Quest> quests = questRepository.findByDepartmentAndStatus(employee.getDepartment(), "AVAILABLE");
        
        return ResponseEntity.ok(quests.stream().map(q -> Map.of(
            "id", q.getId(),
            "title", q.getTitle(),
            "description", q.getDescription(),
            "rewardDays", q.getRewardDays(),
            "status", "AVAILABLE"
        )).collect(Collectors.toList()));
    }
    
    // 사원: 내 퀘스트 목록
    @GetMapping("/my-quests")
    public ResponseEntity<?> getMyQuests(@RequestParam Long employeeId) {
        List<QuestProgress> progresses = progressRepository.findByEmployeeId(employeeId);
        
        return ResponseEntity.ok(progresses.stream().map(p -> {
            Quest quest = questRepository.findById(p.getQuestId()).orElse(null);
            return Map.of(
                "id", p.getId(),
                "questId", p.getQuestId(),
                "title", quest != null ? quest.getTitle() : "",
                "rewardDays", quest != null ? quest.getRewardDays() : 0,
                "status", p.getStatus()
            );
        }).collect(Collectors.toList()));
    }
    
    // 사원: 업무 수락
    @PostMapping("/{questId}/accept")
    public ResponseEntity<?> acceptQuest(@PathVariable Long questId, @RequestBody Map<String, Long> body) {
        Long employeeId = body.get("employeeId");
        
        QuestProgress progress = new QuestProgress();
        progress.setQuestId(questId);
        progress.setEmployeeId(employeeId);
        progress.setStatus("IN_PROGRESS");
        progressRepository.save(progress);
        
        return ResponseEntity.ok(Map.of("message", "업무 수락 완료"));
    }
    
    // 사원: 완료 보고
    @PostMapping("/{questId}/complete")
    public ResponseEntity<?> completeQuest(@PathVariable Long questId, @RequestBody Map<String, Long> body) {
        Long employeeId = body.get("employeeId");
        
        QuestProgress progress = progressRepository.findByQuestIdAndEmployeeId(questId, employeeId)
            .orElseThrow(() -> new RuntimeException("Quest progress not found"));
        
        progress.setStatus("WAITING_APPROVAL");
        progress.setCompletedAt(LocalDateTime.now());
        progressRepository.save(progress);
        
        return ResponseEntity.ok(Map.of("message", "완료 보고됨, 승인 대기 중"));
    }
    
    // 사원: 보상 받기
    @PostMapping("/{questId}/claim")
    public ResponseEntity<?> claimReward(@PathVariable Long questId, @RequestBody Map<String, Long> body) {
        Long employeeId = body.get("employeeId");
        
        QuestProgress progress = progressRepository.findByQuestIdAndEmployeeId(questId, employeeId)
            .orElseThrow(() -> new RuntimeException("Quest progress not found"));
        
        if (!"APPROVED".equals(progress.getStatus())) {
            return ResponseEntity.badRequest().body(Map.of("error", "아직 승인되지 않았습니다"));
        }
        
        Quest quest = questRepository.findById(questId)
            .orElseThrow(() -> new RuntimeException("Quest not found"));
        
        Employee employee = employeeRepository.findById(employeeId)
            .orElseThrow(() -> new RuntimeException("Employee not found"));
        
        employee.setAnnualLeaveBalance(employee.getAnnualLeaveBalance() + quest.getRewardDays());
        employeeRepository.save(employee);
        
        progress.setStatus("CLAIMED");
        progress.setClaimedAt(LocalDateTime.now());
        progressRepository.save(progress);
        
        return ResponseEntity.ok(Map.of(
            "message", "보상 받기 완료",
            "newLeaveBalance", employee.getAnnualLeaveBalance()
        ));
    }
    
    // 부장: 업무 생성
    @PostMapping
    public ResponseEntity<?> createQuest(@RequestBody Map<String, Object> body) {
        Quest quest = new Quest();
        quest.setTitle((String) body.get("title"));
        quest.setDescription((String) body.get("description"));
        quest.setRewardDays(((Number) body.get("rewardDays")).doubleValue());
        quest.setDepartment((String) body.get("department"));
        quest.setCreatedBy(body.get("createdBy") != null ? ((Number) body.get("createdBy")).longValue() : 1L);
        quest.setStatus("AVAILABLE");
        
        Quest saved = questRepository.save(quest);
        
        return ResponseEntity.ok(Map.of(
            "id", saved.getId(),
            "message", "업무 생성 완료"
        ));
    }
    
    // 부장: 내가 만든 업무
    @GetMapping("/my-created")
    public ResponseEntity<?> getMyCreatedQuests(@RequestParam Long managerId) {
        List<Quest> quests = questRepository.findByCreatedBy(managerId);
        
        return ResponseEntity.ok(quests.stream().map(q -> {
            List<QuestProgress> progresses = progressRepository.findByQuestIdAndStatus(q.getId(), "WAITING_APPROVAL");
            String acceptedBy = progresses.isEmpty() ? null : 
                employeeRepository.findById(progresses.get(0).getEmployeeId())
                    .map(Employee::getName).orElse("Unknown");
            
            return Map.of(
                "id", q.getId(),
                "title", q.getTitle(),
                "acceptedBy", acceptedBy != null ? acceptedBy : "",
                "status", progresses.isEmpty() ? "AVAILABLE" : "WAITING_APPROVAL",
                "rewardDays", q.getRewardDays()
            );
        }).collect(Collectors.toList()));
    }
    
    // 부장: 승인
    @PutMapping("/{questId}/approve")
    public ResponseEntity<?> approveQuest(@PathVariable Long questId, @RequestBody Map<String, Long> body) {
        List<QuestProgress> progresses = progressRepository.findByQuestIdAndStatus(questId, "WAITING_APPROVAL");
        
        if (progresses.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "승인 대기 중인 업무가 없습니다"));
        }
        
        QuestProgress progress = progresses.get(0);
        progress.setStatus("APPROVED");
        progress.setApprovedAt(LocalDateTime.now());
        progressRepository.save(progress);
        
        return ResponseEntity.ok(Map.of("message", "승인 완료, 사원이 보상 받을 수 있습니다"));
    }
    
    // 부장: 반려
    @PutMapping("/{questId}/reject")
    public ResponseEntity<?> rejectQuest(@PathVariable Long questId, @RequestBody Map<String, Object> body) {
        List<QuestProgress> progresses = progressRepository.findByQuestIdAndStatus(questId, "WAITING_APPROVAL");
        
        if (progresses.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "승인 대기 중인 업무가 없습니다"));
        }
        
        QuestProgress progress = progresses.get(0);
        progress.setStatus("REJECTED");
        progressRepository.save(progress);
        
        return ResponseEntity.ok(Map.of("message", "반려됨"));
    }
    
    // 부장: 업무 삭제
    @DeleteMapping("/{questId}")
    public ResponseEntity<?> deleteQuest(@PathVariable Long questId) {
        Quest quest = questRepository.findById(questId)
            .orElseThrow(() -> new RuntimeException("Quest not found"));
        
        quest.setStatus("DELETED");
        questRepository.save(quest);
        
        return ResponseEntity.ok(Map.of("message", "업무 삭제됨"));
    }
}
