# Employee Service 구현 문서

## 프로젝트 목표

본 프로젝트의 최종 목표는 실무 환경에서 사용되는 다양한 통신 방식(REST, gRPC, WebSocket)과 이종 데이터 저장소(MySQL, MongoDB, In-Memory)를 통합하여 하나의 엔터프라이즈 자원 관리(ERP) 시스템처럼 동작하는 유연한 마이크로서비스 구조를 구현하는 것이다.

Employee Service는 이 중 REST API 통신과 MySQL 관계형 데이터베이스를 담당하는 첫 번째 마이크로서비스이다.

---

## 1. 과제 요구사항 분석

### 1.1 Employee Service 요구사항 (배점: 20점)

과제 문서에서 요구하는 Employee Service의 핵심 기능:

1. 직원 정보 관리 (CRUD)
   - 직원 생성, 조회, 수정, 삭제 기능 구현
   
2. 통신 프로토콜
   - REST API 사용 (HTTP 기반)
   
3. 데이터 저장소
   - MySQL 관계형 데이터베이스 사용
   
4. 테이블 구조
   - id (BIGINT, PRIMARY KEY, AUTO_INCREMENT)
   - name (VARCHAR(100), NOT NULL)
   - department (VARCHAR(100), NOT NULL)
   - position (VARCHAR(100), NOT NULL)
   - created_at (DATETIME, DEFAULT CURRENT_TIMESTAMP)

### 1.2 REST API 요구사항

과제에서 명시한 API 엔드포인트:

| HTTP Method | URI | 기능 | 요청 예시 | 응답 예시 |
|-------------|-----|------|----------|----------|
| POST | /employees | 직원 생성 | {"name":"Kim","department":"HR","position":"Manager"} | {"id":10} |
| GET | /employees | 직원 목록 조회 | - | [{직원 배열}] |
| GET | /employees?department=HR&position=Manager | 필터링 조회 | - | [{필터링된 직원}] |
| GET | /employees/{id} | 직원 상세 조회 | - | {직원 정보} |
| PUT | /employees/{id} | 직원 수정 | {"department":"Finance","position":"Director"} | {수정된 직원} |
| DELETE | /employees/{id} | 직원 삭제 | - | 204 No Content |

### 1.3 제약사항

과제에서 명시한 중요 제약사항:

1. PUT 요청 시 department와 position만 수정 가능
   - name, id는 수정 불가
   - 이외 필드 수정 요청 시 에러 처리 필요

2. 필드 검증
   - 모든 필드는 필수 (NOT NULL)
   - 빈 값 또는 null 입력 시 에러 반환

3. 다른 서비스와의 연동
   - Approval Request Service에서 직원 ID 검증용으로 사용됨
   - GET /employees/{id} API가 정상 동작해야 함

### 1.4 구현 목표

요구사항을 충족하기 위한 구현 목표:

1. Spring Boot로 REST API 서버 구현
2. MySQL과 JPA 연동
3. CRUD 기능 완전 구현
4. 필터링 조회 지원 (department, position)
5. 입력 검증 (Validation)
6. Docker 컨테이너화
7. 다른 서비스에서 호출 가능하도록 설계

---

## 2. 기술 스택 선택 및 비교

### 2.1 프로그래밍 언어: Java 17

| 옵션 | 장점 | 단점 | 선택 |
|------|------|------|------|
| **Java 17** | Spring 생태계, 안정성, 기업 표준 | 상대적으로 무거움 | |
| Node.js | 빠른 개발, 경량 | 타입 안정성 부족 | |
| Python | 간결한 문법 | 성능 낮음 | |

**선택 이유**: Spring Boot와 최적 호환, 실무 표준, 타입 안정성

### 2.2 프레임워크: Spring Boot 3.3.13

| 옵션 | 장점 | 단점 | 선택 |
|------|------|------|------|
| **Spring Boot** | 자동 설정, 풍부한 생태계 | 학습 곡선 | |
| Express.js | 간단, 빠름 | 기능 부족 | |
| FastAPI | 빠름, 자동 문서화 | 생태계 작음 | |

**선택 이유**: REST API 개발 표준, 자동 설정으로 빠른 개발, 실무 경험 필수

### 2.3 데이터베이스: MySQL 8.0

| 옵션 | 장점 | 단점 | 선택 |
|------|------|------|------|
| **MySQL** | 관계형, 안정적, 무료 | NoSQL 대비 유연성 낮음 | |
| PostgreSQL | 고급 기능 | 복잡함 | |
| MongoDB | 유연한 스키마 | 관계형 데이터에 부적합 | |

**선택 이유**: 
- 직원 정보는 구조화된 데이터 (id, name, department, position)
- 관계형 데이터베이스가 적합
- MySQL은 가장 널리 사용되는 오픈소스 RDBMS

### 2.4 ORM: Spring Data JPA

| 옵션 | 장점 | 단점 | 선택 |
|------|------|------|------|
| **Spring Data JPA** | SQL 불필요, 자동 쿼리 생성 | 복잡한 쿼리 어려움 | |
| MyBatis | SQL 직접 제어 | 코드 많음 | |
| JDBC | 완전한 제어 | 보일러플레이트 많음 | |

**선택 이유**: 
- CRUD는 단순하므로 JPA로 충분
- `findByDepartment` 같은 메서드 이름만으로 쿼리 자동 생성
- 개발 속도 향상

### 2.5 빌드 도구: Maven

| 옵션 | 장점 | 단점 | 선택 |
|------|------|------|------|
| **Maven** | 표준, 안정적 | XML 장황함 | |
| Gradle | 빠름, 간결 | 학습 필요 | |

**선택 이유**: Spring Boot 기본 지원, 실무 표준

### 2.6 최종 기술 스택

```
Language:   Java 17
Framework:  Spring Boot 3.3.13
Database:   MySQL 8.0
ORM:        Spring Data JPA (Hibernate)
Build:      Maven 3.9
Container:  Docker
```

---

## 3. 프로젝트 구조

```
employee-service/
├── src/main/java/com/erp/employee/
│   ├── entity/
│   │   └── Employee.java              # 데이터베이스 테이블과 매핑되는 Entity
│   ├── repository/
│   │   └── EmployeeRepository.java    # 데이터베이스 접근 인터페이스
│   ├── service/
│   │   └── EmployeeService.java       # 비즈니스 로직 처리
│   ├── controller/
│   │   └── EmployeeController.java    # REST API 엔드포인트
│   ├── dto/
│   │   ├── EmployeeRequest.java       # 직원 생성 요청 데이터
│   │   └── EmployeeUpdateRequest.java # 직원 수정 요청 데이터
│   └── EmployeeServiceApplication.java # 애플리케이션 시작점
├── src/main/resources/
│   └── application.yml                 # 설정 파일
├── pom.xml                             # Maven 의존성 관리
└── Dockerfile                          # Docker 이미지 빌드 설정
```

---

## 3. 구현 내용

### 3.1 데이터베이스 설계

테이블 구조 (employees)

| 컬럼명 | 타입 | 제약조건 | 설명 |
|--------|------|---------|------|
| id | BIGINT | PRIMARY KEY, AUTO_INCREMENT | 직원 고유 ID |
| name | VARCHAR(100) | NOT NULL | 직원 이름 |
| department | VARCHAR(100) | NOT NULL | 부서 (예: HR, Finance) |
| position | VARCHAR(100) | NOT NULL | 직책 (예: Manager, Director) |
| created_at | DATETIME | NOT NULL | 생성 시간 (자동 기록) |

Entity 구현 (Employee.java)

```java
@Entity
@Table(name = "employees")
public class Employee {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, length = 100)
    private String name;
    
    @Column(nullable = false, length = 100)
    private String department;
    
    @Column(nullable = false, length = 100)
    private String position;
    
    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
```

핵심 어노테이션 설명:
- @Entity: 이 클래스가 데이터베이스 테이블과 매핑됨을 표시
- @GeneratedValue(strategy = GenerationType.IDENTITY): MySQL의 AUTO_INCREMENT 사용
- @CreationTimestamp: 데이터 생성 시 현재 시간 자동 기록
- updatable = false: created_at은 한 번 생성되면 수정 불가

### 3.2 데이터 접근 계층 (Repository)

EmployeeRepository.java

```java
public interface EmployeeRepository extends JpaRepository<Employee, Long> {
    List<Employee> findByDepartment(String department);
    List<Employee> findByPosition(String position);
    List<Employee> findByDepartmentAndPosition(String department, String position);
}
```

Spring Data JPA의 자동 쿼리 생성:
- JpaRepository 상속만으로 기본 CRUD 메서드 자동 제공 (save, findById, findAll, delete 등)
- 메서드 이름 규칙에 따라 쿼리 자동 생성
  - findByDepartment --> SELECT * FROM employees WHERE department = ?
  - findByDepartmentAndPosition --> SELECT * FROM employees WHERE department = ? AND position = ?

### 3.3 비즈니스 로직 (Service)

EmployeeService.java 주요 메서드

```java
// 필터링 조회 로직
public List<Employee> getEmployees(String department, String position) {
    if (department != null && position != null) {
        return employeeRepository.findByDepartmentAndPosition(department, position);
    } else if (department != null) {
        return employeeRepository.findByDepartment(department);
    } else if (position != null) {
        return employeeRepository.findByPosition(position);
    } else {
        return employeeRepository.findAll();
    }
}
```

구현 의도:
- 파라미터 조합에 따라 다른 쿼리 실행
- 유연한 검색 기능 제공 (부서만, 직책만, 둘 다, 전체)

### 3.4 REST API (Controller)

구현된 API 목록

| HTTP Method | URI | 기능 | Request Body | Response |
|-------------|-----|------|--------------|----------|
| POST | /employees | 직원 생성 | {"name":"Kim","department":"HR","position":"Manager"} | {"id":1} |
| GET | /employees | 전체 조회 | - | [{직원 목록}] |
| GET | /employees?department=HR | 부서별 조회 | - | [{직원 목록}] |
| GET | /employees/{id} | 상세 조회 | - | {직원 정보} |
| PUT | /employees/{id} | 수정 | {"department":"Finance","position":"Director"} | {직원 정보} |
| DELETE | /employees/{id} | 삭제 | - | 204 No Content |

PUT 요청 제약사항:
- 요구사항에 따라 department와 position만 수정 가능
- name과 id는 수정 불가
- 이를 위해 별도의 DTO(EmployeeUpdateRequest) 사용

```java
public class EmployeeUpdateRequest {
    private String department;  // 수정 가능
    private String position;    // 수정 가능
    // name, id는 포함하지 않음 (수정 불가)
}
```

### 3.5 입력 검증 (Validation)

EmployeeRequest.java

```java
public class EmployeeRequest {
    @NotBlank(message = "이름은 필수입니다")
    private String name;
    
    @NotBlank(message = "부서는 필수입니다")
    private String department;
    
    @NotBlank(message = "직책은 필수입니다")
    private String position;
}
```

검증 동작 방식:
- Controller에서 @Valid 어노테이션 사용
- 필수 필드가 비어있으면 자동으로 400 Bad Request 반환
- 별도의 검증 코드 작성 불필요

---

## 4. 설정 파일

application.yml

```yaml
spring:
  datasource:
    url: jdbc:mysql://mysql:3306/erp
    username: root
    password: root1234
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true
```

설정 설명:
- url: jdbc:mysql://mysql:3306/erp
  - Docker Compose 환경에서는 서비스 이름(mysql)으로 접속
  - 로컬 환경에서는 localhost로 변경 필요
- ddl-auto: update
  - Entity 변경 시 테이블 구조 자동 업데이트
  - 개발 환경에서만 사용 (운영 환경에서는 validate 권장)
- show-sql: true
  - 실행되는 SQL 쿼리를 콘솔에 출력 (디버깅용)

---

## 5. Docker 설정

Dockerfile

```dockerfile
# Stage 1: Build
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Multi-stage Build 사용 이유:
- Stage 1 (Build): Maven과 JDK를 사용하여 JAR 파일 생성
- Stage 2 (Runtime): 빌드된 JAR만 복사하여 JRE로 실행
- 효과: 최종 이미지 크기 약 60% 감소 (500MB --> 200MB)
- alpine 이미지: 경량 Linux 배포판으로 추가 용량 절감

---

## 6. 실행 방법

### 6.1 로컬 실행 (MySQL 필요)

1단계: MySQL 실행
```bash
docker run -d \
  --name mysql \
  -e MYSQL_ROOT_PASSWORD=root1234 \
  -e MYSQL_DATABASE=erp \
  -p 3306:3306 \
  mysql:8.0
```

2단계: application.yml 수정
```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/erp  # mysql --> localhost
```

3단계: 애플리케이션 실행
```bash
cd employee-service
mvn spring-boot:run
```

### 6.2 Docker로 실행

이미지 빌드
```bash
docker build -t employee-service:1.0 .
```

컨테이너 실행
```bash
docker run -d \
  --name employee-service \
  -p 8081:8081 \
  --link mysql:mysql \
  employee-service:1.0
```

---

## 7. API 테스트

### 7.1 직원 생성 (POST)

요청
```bash
curl -X POST http://localhost:8081/employees \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Kim",
    "department": "HR",
    "position": "Manager"
  }'
```

응답
```json
{
  "id": 1
}
```

### 7.2 전체 조회 (GET)

요청
```bash
curl http://localhost:8081/employees
```

응답
```json
[
  {
    "id": 1,
    "name": "Kim",
    "department": "HR",
    "position": "Manager",
    "createdAt": "2025-11-27T10:00:00"
  }
]
```

### 7.3 필터링 조회 (GET with Query Parameters)

부서별 조회
```bash
curl "http://localhost:8081/employees?department=HR"
```

부서 + 직책 조회
```bash
curl "http://localhost:8081/employees?department=HR&position=Manager"
```

### 7.4 상세 조회 (GET)

요청
```bash
curl http://localhost:8081/employees/1
```

### 7.5 수정 (PUT)

요청
```bash
curl -X PUT http://localhost:8081/employees/1 \
  -H "Content-Type: application/json" \
  -d '{
    "department": "Finance",
    "position": "Director"
  }'
```

응답
```json
{
  "id": 1,
  "name": "Kim",
  "department": "Finance",
  "position": "Director",
  "createdAt": "2025-11-27T10:00:00"
}
```

주의: name은 변경되지 않음 (요구사항)

### 7.6 삭제 (DELETE)

요청
```bash
curl -X DELETE http://localhost:8081/employees/1
```

응답
```
204 No Content
```

---

## 8. 학습 내용 정리

### 8.1 Spring Boot 핵심 개념

Layered Architecture
- Controller: HTTP 요청/응답 처리
- Service: 비즈니스 로직
- Repository: 데이터베이스 접근
- Entity: 데이터베이스 테이블 매핑

Dependency Injection
- @RequiredArgsConstructor로 생성자 주입
- Spring이 자동으로 의존성 관리

### 8.2 Spring Data JPA

자동 쿼리 생성
- 메서드 이름만으로 쿼리 자동 생성
- SQL 작성 불필요

트랜잭션 관리
- @Transactional로 자동 커밋/롤백
- 예외 발생 시 자동 롤백

### 8.3 REST API 설계

HTTP Method 의미
- POST: 생성
- GET: 조회
- PUT: 수정
- DELETE: 삭제

상태 코드
- 200 OK: 성공
- 204 No Content: 삭제 성공
- 400 Bad Request: 잘못된 요청
- 404 Not Found: 리소스 없음

### 8.4 Docker

Multi-stage Build
- 빌드 환경과 실행 환경 분리
- 최종 이미지 경량화

컨테이너 네트워킹
- --link로 컨테이너 간 통신
- 서비스 이름으로 DNS 해석

---

## 9. 다음 단계

Employee Service는 다른 서비스에서 직원 ID 검증용으로 사용된다.

Approval Request Service에서의 활용:
- 결재 요청 시 requesterId 검증
- 결재자 approverId 검증
- REST API 호출: GET /employees/{id}

---

## 10. 참고 자료

- Spring Boot 공식 문서: https://spring.io/projects/spring-boot
- Spring Data JPA: https://spring.io/projects/spring-data-jpa
- Docker Multi-stage Build: https://docs.docker.com/build/building/multi-stage/
- REST API 설계 가이드: https://restfulapi.net/
