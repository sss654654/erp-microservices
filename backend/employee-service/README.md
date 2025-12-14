# Employee Service

직원 정보 관리 및 게이미피케이션 기능을 담당하는 마이크로서비스

## 책임

- 직원 CRUD (생성, 조회, 수정, 삭제)
- 연차 관리 (잔여 일수 조회, 차감)
- 출석 체크 (30일 출석 → 연차 1일 자동 지급)
- 퀘스트 시스템 (부장이 업무 생성 → 사원 완료 → 연차 보상)

## 기술 스택

- **Framework**: Spring Boot 3.3.5
- **Database**: MySQL 8.0 (RDS)
- **ORM**: Spring Data JPA
- **Port**: 8081

## 데이터베이스 스키마

### employees
```sql
CREATE TABLE employees (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE,
  department VARCHAR(100) NOT NULL,
  position VARCHAR(100) NOT NULL,
  annual_leave_balance DOUBLE DEFAULT 0.0,
  attendance_count INT DEFAULT 0,
  created_at TIMESTAMP
);
```

### attendance
```sql
CREATE TABLE attendance (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  employee_id BIGINT NOT NULL,
  check_in_time TIMESTAMP NOT NULL,
  check_out_time TIMESTAMP,
  work_hours DOUBLE,
  status VARCHAR(20) DEFAULT 'IN_PROGRESS',
  created_at TIMESTAMP
);
```

### leaves
```sql
CREATE TABLE leaves (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  employee_id BIGINT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  days INT NOT NULL,
  reason TEXT,
  status VARCHAR(20) DEFAULT 'PENDING',
  created_at TIMESTAMP
);
```

### quests
```sql
CREATE TABLE quests (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  reward_days DOUBLE NOT NULL,
  department VARCHAR(50) NOT NULL,
  created_by BIGINT NOT NULL,
  status VARCHAR(20) DEFAULT 'AVAILABLE',
  created_at TIMESTAMP
);
```

### quest_progress
```sql
CREATE TABLE quest_progress (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  quest_id BIGINT NOT NULL,
  employee_id BIGINT NOT NULL,
  status VARCHAR(20) DEFAULT 'IN_PROGRESS',
  started_at TIMESTAMP,
  completed_at TIMESTAMP
);
```

## 주요 API

### 직원 관리
- `POST /employees` - 직원 생성
- `GET /employees` - 직원 목록 조회 (department, position 필터링)
- `GET /employees/{id}` - 직원 상세 조회
- `PUT /employees/{id}` - 직원 정보 수정
- `DELETE /employees/{id}` - 직원 삭제

### 연차 관리
- `GET /employees/{id}/leave-balance` - 연차 잔여 일수 조회
- `POST /employees/{id}/deduct-leave` - 연차 차감 (결재 승인 시 호출)
- `PUT /employees/{id}/leave-balance` - 연차 조정 (부장 권한)

### 출석 체크
- `POST /attendance/check-in` - 출석 체크 (30일마다 연차 1일 지급)
- `GET /attendance/employee/{employeeId}` - 출석 기록 조회

### 퀘스트 시스템
- `POST /quests` - 퀘스트 생성 (부장)
- `GET /quests` - 퀘스트 목록 조회
- `POST /quests/{questId}/accept` - 퀘스트 수락 (사원)
- `POST /quests/{questId}/complete` - 퀘스트 완료 (사원)
- `POST /quest-progress/{progressId}/approve` - 퀘스트 승인 및 연차 지급 (부장)

## 핵심 로직

### 출석 30일 → 연차 1일 자동 지급
```java
@PostMapping("/check-in")
public ResponseEntity<?> checkIn(@RequestParam Long employeeId) {
    Employee employee = employeeService.getEmployeeById(employeeId);
    
    // 출석 기록 생성
    Attendance attendance = new Attendance();
    attendance.setEmployeeId(employeeId);
    attendance.setCheckInTime(LocalDateTime.now());
    attendanceRepository.save(attendance);
    
    // 출석 횟수 증가
    employee.setAttendanceCount(employee.getAttendanceCount() + 1);
    
    // 30일마다 연차 1일 지급
    if (employee.getAttendanceCount() % 30 == 0) {
        employee.setAnnualLeaveBalance(employee.getAnnualLeaveBalance() + 1.0);
    }
    
    employeeService.save(employee);
    return ResponseEntity.ok(Map.of("message", "출석 완료"));
}
```

### 퀘스트 승인 시 연차 지급
```java
@PostMapping("/{progressId}/approve")
public ResponseEntity<?> approveQuest(@PathVariable Long progressId) {
    QuestProgress progress = questProgressRepository.findById(progressId).orElseThrow();
    Quest quest = questRepository.findById(progress.getQuestId()).orElseThrow();
    Employee employee = employeeService.getEmployeeById(progress.getEmployeeId());
    
    // 연차 지급
    employee.setAnnualLeaveBalance(employee.getAnnualLeaveBalance() + quest.getRewardDays());
    employeeService.save(employee);
    
    progress.setStatus("APPROVED");
    questProgressRepository.save(progress);
    
    return ResponseEntity.ok(Map.of("message", "승인 완료", "reward", quest.getRewardDays()));
}
```

## 로컬 실행

```bash
# MySQL 실행 (Docker)
docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=erp mysql:8.0

# 애플리케이션 실행
mvn spring-boot:run
```

## 환경 변수

```yaml
SPRING_DATASOURCE_URL: jdbc:mysql://localhost:3306/erp
SPRING_DATASOURCE_USERNAME: root
SPRING_DATASOURCE_PASSWORD: root
```
