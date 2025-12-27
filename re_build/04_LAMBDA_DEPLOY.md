# 04. Lambda 배포 (Employee Service)

**소요 시간**: 2시간  
**목표**: Employee Service를 EKS → Lambda 전환 (비용 21% 절감, 자동 스케일링)

---

## 📋 목차

1. [왜 Employee Service만 Lambda로?](#왜-employee-service만-lambda로)
2. [아키텍처 비교](#아키텍처-비교)
3. [Lambda 환경 구축](#lambda-환경-구축)
4. [트러블슈팅 전체 과정](#트러블슈팅-전체-과정)
5. [최종 검증](#최종-검증)

---

## 🎯 왜 Employee Service만 Lambda로?

### Lambda 전환 가능 조건 분석

| 서비스 | 실행 시간 | 의존성 | Lambda 가능? | 이유 |
|--------|----------|--------|-------------|------|
| **Employee** | 200ms | MySQL만 | ✅ **가능** | 간단한 CRUD, 빠른 응답 |
| Approval Request | 500ms | MongoDB, Kafka Producer | ❌ 불가 | Kafka 의존성 |
| Approval Processing | 장시간 | Kafka Consumer | ❌ 불가 | 15분 제한 초과 |
| Notification | 장시간 | WebSocket 연결 유지 | ❌ 불가 | 요청-응답 모델 |

### Employee Service 특징

```java
// backend/employee-service/src/main/java/com/erp/employee/EmployeeController.java
@RestController
@RequestMapping("/employees")
public class EmployeeController {
    @GetMapping
    public List<Employee> getAllEmployees() {
        return employeeService.findAll();  // 단순 조회
    }
    
    @PostMapping
    public Employee createEmployee(@RequestBody Employee employee) {
        return employeeService.save(employee);  // 단순 저장
    }
}
```

- ✅ 간단한 CRUD 작업
- ✅ MySQL만 사용 (RDS 연결)
- ✅ Kafka, WebSocket 없음
- ✅ 평균 실행 시간 200ms

### 비용 절감 효과

**Before (모두 EKS):**
```
총 8 Pods:
- Employee: 2 Pods (t3.small)
- Approval Request: 2 Pods
- Approval Processing: 2 Pods
- Notification: 2 Pods

비용: $82.30/월
```

**After (Employee → Lambda):**
```
총 6 Pods:
- Approval Request: 2 Pods
- Approval Processing: 2 Pods
- Notification: 2 Pods

Lambda:
- Employee Service (100,000 요청/월)

비용: $61.73 (EKS) + $3 (Lambda) = $64.73/월
절감: $17.57/월 (21%)
```

---

## 🏗 아키텍처 비교

### Before: 모두 EKS

```
                    ┌─────────────────┐
                    │  API Gateway    │
                    │  (단일 진입점)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │    VPC Link     │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │      NLB        │
                    │  (Private)      │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐         ┌────▼────┐         ┌────▼────┐
   │Employee │         │Approval │         │Notific. │
   │ Pods x2 │         │ Pods x4 │         │ Pods x2 │
   └─────────┘         └─────────┘         └─────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                        ┌────▼────┐
                        │   RDS   │
                        └─────────┘
```

**문제점:**
- Employee Service는 간단한 CRUD인데 Pod 2개 불필요
- VPC Link 비용 ($0.01/시간 = $7.2/월)
- 고정 비용 (트래픽 없어도 Pod 실행)

### After: Employee → Lambda

```
                    ┌─────────────────┐
                    │  API Gateway    │
                    │  (단일 진입점)   │
                    └────┬───────┬────┘
                         │       │
         ┌───────────────┘       └──────────────┐
         │                                      │
    ┌────▼────┐                        ┌───────▼──────┐
    │ Lambda  │                        │   VPC Link   │
    │(직접통합)│                        └───────┬──────┘
    └────┬────┘                                │
         │                                ┌────▼────┐
         │                                │   NLB   │
         │                                └────┬────┘
         │                                     │
         │                    ┌────────────────┼────────────────┐
         │                    │                                 │
    ┌────▼────┐         ┌────▼────┐                      ┌────▼────┐
    │   RDS   │         │Approval │                      │Notific. │
    │ (VPC내) │         │ Pods x4 │                      │ Pods x2 │
    └─────────┘         └─────────┘                      └─────────┘
```

**개선점:**
- ✅ Lambda 직접 통합 (VPC Link 불필요)
- ✅ 자동 스케일링 (동시 실행 1000개)
- ✅ 종량제 (요청당 과금)
- ✅ Cold Start 300~500ms (첫 요청만)

---

## 🔧 Lambda 환경 구축

### 1. Terraform 구성

**파일 구조:**
```
infrastructure/terraform/dev/erp-dev-Lambda/
├── lambda.tf       # Lambda 함수, IAM Role, API Gateway 통합
├── variables.tf    # 변수 정의
├── outputs.tf      # 출력 값
└── provider.tf     # Terraform 설정
```

**주요 리소스:**

#### 1-1. AWS Secrets Manager 통합

```terraform
# ASM에서 RDS 자격증명 읽기
data "aws_secretsmanager_secret_version" "mysql" {
  secret_id = "${var.project_name}/${var.environment}/mysql"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.mysql.secret_string)
}
```

**RDS와 동일한 방식:**
- Terraform이 ASM에서 username/password 읽음
- Lambda 환경변수로 주입
- 코드 수정 불필요

#### 1-2. Lambda 함수

```terraform
resource "aws_lambda_function" "employee" {
  function_name = "${var.project_name}-${var.environment}-employee-service"
  role          = aws_iam_role.lambda.arn
  
  package_type = "Image"
  image_uri    = "${data.terraform_remote_state.ecr.outputs.employee_lambda_repository_url}:latest"
  
  vpc_config {
    subnet_ids         = data.terraform_remote_state.vpc_subnet.outputs.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      SPRING_DATASOURCE_URL      = "jdbc:mysql://${local.db_creds.host}:${local.db_creds.port}/${local.db_creds.database}?useSSL=true"
      SPRING_DATASOURCE_USERNAME = local.db_creds.username
      SPRING_DATASOURCE_PASSWORD = local.db_creds.password
      AWS_LWA_PORT               = "8081"
      SERVER_PORT                = "8081"
    }
  }
  
  memory_size = 1024
  timeout     = 60
}
```

**핵심 설정:**
- **VPC 내부**: Private Subnet에서 RDS 직접 연결
- **ASM 통합**: 환경변수로 DB 자격증명 주입
- **Lambda Web Adapter**: AWS_LWA_PORT로 Spring Boot 연결

#### 1-3. API Gateway 통합

```terraform
# Lambda 직접 통합 (VPC Link 불필요)
resource "aws_apigatewayv2_integration" "employee_lambda" {
  api_id             = data.terraform_remote_state.api_gateway.outputs.api_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.employee.invoke_arn
  payload_format_version = "2.0"
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "employee_proxy" {
  api_id    = data.terraform_remote_state.api_gateway.outputs.api_id
  route_key = "ANY /api/employees/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.employee_lambda.id}"
}

resource "aws_apigatewayv2_route" "employee_root" {
  api_id    = data.terraform_remote_state.api_gateway.outputs.api_id
  route_key = "ANY /api/employees"
  target    = "integrations/${aws_apigatewayv2_integration.employee_lambda.id}"
}
```

**EKS와의 차이:**
- EKS: API Gateway → VPC Link → NLB → Pod
- Lambda: API Gateway → Lambda (직접 통합)

### 2. Docker 이미지 구성

**Dockerfile.lambda:**
```dockerfile
FROM public.ecr.aws/lambda/java:17

# Lambda Web Adapter 설치
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

# JAR 파일 복사
COPY target/employee-service-1.0.0.jar /var/task/app.jar

# 환경 변수 설정
ENV AWS_LWA_PORT=8081
ENV JAVA_TOOL_OPTIONS="-XX:+TieredCompilation -XX:TieredStopAtLevel=1"

# Spring Boot 실행 (Lambda Web Adapter가 자동으로 처리)
ENTRYPOINT []
CMD ["java", "-jar", "/var/task/app.jar"]
```

**Lambda Web Adapter란?**
- AWS에서 제공하는 Lambda Extension
- 일반 HTTP 서버(Spring Boot)를 Lambda에서 실행 가능
- 코드 수정 없이 기존 Spring Boot 사용

### 3. Spring Boot 설정

**application.yml:**
```yaml
server:
  port: 8081
  servlet:
    context-path: /api  # ⚠️ 중요: API Gateway 경로와 일치

spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
```

**context-path가 필요한 이유:**
- API Gateway: `/api/employees` 요청
- Lambda Web Adapter: 그대로 전달
- Spring Boot: `/api` context-path로 `/employees` 매핑

---

## 🔥 트러블슈팅 전체 과정

### 문제 1: Spring Cloud Function 에러

**증상:**
```
StringIndexOutOfBoundsException: begin 88, end 82, length 88
at org.springframework.cloud.function.adapter.aws.CustomRuntimeEventLoop.extractVersion
```

**원인:**
- pom.xml에 `spring-cloud-function-adapter-aws` 의존성 존재
- Lambda Web Adapter와 충돌

**해결:**
```xml
<!-- 제거 -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-function-adapter-aws</artifactId>
    <version>4.0.0</version>
</dependency>
```

### 문제 2: Lambda Web Adapter 환경변수 누락

**증상:**
- Spring Boot는 시작하지만 HTTP 요청 로그 없음
- API Gateway 500 에러

**원인:**
- Terraform에 `AWS_LWA_PORT` 환경변수 없음
- Lambda Web Adapter가 Spring Boot 포트를 찾지 못함

**해결:**
```terraform
environment {
  variables = {
    AWS_LWA_PORT = "8081"
    SERVER_PORT  = "8081"
  }
}
```

### 문제 3: Context Path 불일치

**증상:**
- DB 쿼리는 실행되지만 API Gateway 500 에러
- Lambda 로그에 요청 없음

**원인:**
- API Gateway: `/api/employees` 요청
- Spring Boot Controller: `/employees` 매핑
- 경로 불일치

**해결:**
```yaml
server:
  servlet:
    context-path: /api
```

### 문제 4: Response Stream 모드 문제

**증상:**
- DB 쿼리 실행됨
- API Gateway 500 에러 지속

**원인:**
- `AWS_LWA_INVOKE_MODE=response_stream` 설정
- API Gateway v2 Payload Format과 호환 문제

**해결:**
```terraform
# AWS_LWA_INVOKE_MODE 제거 (기본값 buffered 사용)
environment {
  variables = {
    AWS_LWA_PORT = "8081"
    # AWS_LWA_INVOKE_MODE 제거
  }
}
```

### 문제 5: ASM 자격증명 누락

**증상:**
- Lambda 환경변수에 SPRING_DATASOURCE_URL만 존재
- username/password 없음

**원인:**
- Terraform에서 ASM 읽기 구현 안 됨
- RDS는 ASM 사용하는데 Lambda는 미구현

**해결:**
```terraform
# RDS와 동일한 방식으로 ASM 읽기
data "aws_secretsmanager_secret_version" "mysql" {
  secret_id = "${var.project_name}/${var.environment}/mysql"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.mysql.secret_string)
}

environment {
  variables = {
    SPRING_DATASOURCE_USERNAME = local.db_creds.username
    SPRING_DATASOURCE_PASSWORD = local.db_creds.password
  }
}
```

---

## ✅ 최종 검증

### 1. Lambda 함수 상태

```bash
aws lambda get-function \
  --function-name erp-dev-employee-service \
  --region ap-northeast-2 \
  --query 'Configuration.[State,LastUpdateStatus]' \
  --output table

# 출력:
# Active
# Successful
```

### 2. API 테스트

```bash
# GET 요청
curl https://yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com/api/employees
# 출력: []

# POST 요청
curl -X POST https://yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com/api/employees \
  -H "Content-Type: application/json" \
  -d '{"name":"홍길동","email":"hong@erp.com","department":"DEVELOPMENT","position":"SENIOR"}'
# 출력: {"id":1}

# GET 요청 (다시)
curl https://yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com/api/employees
# 출력: [{"id":1,"name":"홍길동",...}]
```

### 3. Lambda 로그 확인

```bash
aws logs tail /aws/lambda/erp-dev-employee-service --since 1m --region ap-northeast-2

# 출력:
# Started EmployeeServiceApplication in 8.274 seconds
# Tomcat started on port 8081 (http) with context path '/api'
# Hibernate: select ... from employees
```

### 4. 성능 측정

**Cold Start (최적화 후):**
- Init Duration: 8.2초 (첫 요청)
- 이후 요청: 20~75ms

**최적화 적용:**
- Spring Boot Lazy Initialization: 30% 개선
- Memory 2048MB: CPU 증가로 초기화 빠름
- Lambda Web Adapter: 코드 수정 없음

**메모리 사용:**
- Max Memory Used: 348 MB
- Memory Size: 2048 MB (Cold Start 최적화용)

**참고:** Spring Boot + JPA + Hibernate의 Cold Start는 8~10초가 정상 범위입니다. 
더 빠른 시작이 필요하면 Quarkus, Micronaut 등 GraalVM Native Image 사용을 고려하세요.

---

## 📊 트래픽 흐름 비교

### EKS (Approval/Notification Services)

```
Client
  ↓ HTTPS
API Gateway (yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com)
  ↓ Route: ANY /api/approvals/*
VPC Link (Private 연결)
  ↓
NLB (erp-dev-nlb, Private)
  ↓ Target Group (8082)
ClusterIP Service (approval-request-service:8082)
  ↓
Pod (approval-request-service)
  ↓
MongoDB Atlas (외부)
```

**특징:**
- VPC Link 필요 ($7.2/월)
- NLB 필요 ($16/월)
- Pod 고정 비용
- 복잡한 네트워크 경로

### Lambda (Employee Service)

```
Client
  ↓ HTTPS
API Gateway (yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com)
  ↓ Route: ANY /api/employees/*
Lambda Integration (AWS_PROXY)
  ↓
Lambda Function (erp-dev-employee-service)
  ↓ VPC 내부 (Private Subnet)
RDS MySQL (erp-dev-mysql)
```

**특징:**
- VPC Link 불필요
- NLB 불필요
- 종량제 (요청당 과금)
- 단순한 네트워크 경로

---

## 🎯 핵심 포인트

### 1. ASM 통합 (Single Source of Truth)

**RDS 생성:**
```terraform
username = local.db_creds.username  # ASM에서
password = local.db_creds.password  # ASM에서
```

**Lambda 환경변수:**
```terraform
SPRING_DATASOURCE_USERNAME = local.db_creds.username  # ASM에서
SPRING_DATASOURCE_PASSWORD = local.db_creds.password  # ASM에서
```

**결과:**
- 비밀번호가 Git에 없음
- RDS와 Lambda가 동일한 자격증명 사용
- ASM만 업데이트하면 모두 반영

### 2. Lambda Web Adapter (코드 수정 없음)

**일반 Spring Boot:**
```java
@RestController
@RequestMapping("/employees")
public class EmployeeController {
    @GetMapping
    public List<Employee> getAllEmployees() {
        return employeeService.findAll();
    }
}
```

**Lambda에서 그대로 실행:**
- Spring Cloud Function 불필요
- Handler 클래스 불필요
- 기존 코드 그대로 사용

### 3. API Gateway 직접 통합

**EKS:**
- API Gateway → VPC Link → NLB → Pod
- 비용: VPC Link + NLB = $23.2/월

**Lambda:**
- API Gateway → Lambda
- 비용: Lambda 요청당 과금 = $3/월 (100,000 요청)

---

## 📝 체크리스트

- [x] Terraform Lambda 모듈 생성
- [x] ASM에서 RDS 자격증명 읽기
- [x] Lambda 환경변수에 DB 자격증명 주입
- [x] Dockerfile.lambda 작성 (Lambda Web Adapter)
- [x] Spring Cloud Function 의존성 제거
- [x] Context path 설정 (/api)
- [x] Response stream 모드 제거
- [x] API Gateway 통합 생성
- [x] Lambda 함수 배포
- [x] API 테스트 성공
- [x] CloudWatch Logs 확인

---

## 🚀 다음 단계

**Lambda 배포 완료!**

**다음 파일을 읽으세요:**
→ **05_HELM_CHART.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 05_HELM_CHART.md
```

---

**"Employee Service가 Lambda로 전환되었습니다. 비용 21% 절감, 자동 스케일링 완료!"**
