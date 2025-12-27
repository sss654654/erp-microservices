# 04. Lambda 배포 (Employee Service)

**소요 시간**: 2시간  
**목표**: Employee Service를 EKS → Lambda 전환 (비용 21% 절감)

---

##  현재 상황 분석

### 현재 구조 (모두 EKS)

```
API Gateway (단일 진입점)
  ├─ /api/employees/*     → VPC Link → NLB → Employee Pods (2개)
  ├─ /api/approvals/*     → VPC Link → NLB → Approval Pods (4개)
  └─ /api/notifications/* → VPC Link → NLB → Notification Pods (2개)

총 8 Pods
비용: $82.30/월
```

**문제:**
-  Employee Service는 간단한 CRUD (MySQL만)
-  실행 시간 200ms (Lambda 적합)
-  EKS Pod 2개 불필요 (비용 낭비)

### 왜 Employee Service만 Lambda로?

**Lambda 전환 가능 조건 분석:**

| 서비스 | 실행 시간 | 의존성 | Lambda 가능? | 이유 |
|--------|----------|--------|-------------|------|
| **Employee** | 200ms | MySQL만 |  **가능** | 간단한 CRUD, 빠른 응답 |
| Approval Request | 500ms | MongoDB, Kafka Producer |  불가 | Kafka 의존성 |
| Approval Processing | 장시간 | Kafka Consumer |  불가 | 15분 제한 초과 |
| Notification | 장시간 | WebSocket 연결 유지 |  불가 | 요청-응답 모델 |

**실제 코드 확인:**
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

**특징:**
-  간단한 CRUD 작업
-  MySQL만 사용 (RDS 연결)
-  Kafka, WebSocket 없음
-  평균 실행 시간 200ms

---

##  개선 목표

### After (Employee → Lambda)

```
API Gateway (단일 진입점)
  ├─ /api/employees/*     → Lambda (직접 통합)  VPC Link 불필요
  ├─ /api/approvals/*     → VPC Link → NLB → Approval Pods (4개)
  └─ /api/notifications/* → VPC Link → NLB → Notification Pods (2개)

총 6 Pods + Lambda
비용: $61.73 (EKS) + $3 (Lambda) = $64.73/월
절감: $17.57/월 (21%)
```

**장점:**
-  비용 21% 절감
-  자동 스케일링 (동시 실행 1000개)
-  VPC Link 불필요 (Lambda 직접 통합)
-  Cold Start 300~500ms (첫 요청만)

---

##  Step 1: Terraform Lambda 모듈 생성 (40분)

### 1-1. 폴더 생성

```bash
cd infrastructure/terraform/dev
mkdir -p erp-dev-Lambda
cd erp-dev-Lambda
```

### 1-2. main.tf 생성

```bash
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "erp-terraform-state-subin-bucket"
    key            = "dev/lambda/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "erp-terraform-locks"
    encrypt        = true
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Remote State 참조
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/subnet/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "security_groups" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/security-groups/eks-sg/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/databases/rds/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/api-gateway/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Lambda Security Group
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

# Lambda IAM Role
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Lambda VPC Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Secrets Manager Policy
resource "aws_iam_role_policy" "lambda_secrets" {
  role = aws_iam_role.lambda.id
  name = "lambda-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:erp/*"
    }]
  })
}

# ECR Repository (Lambda 컨테이너 이미지용)
resource "aws_ecr_repository" "employee_lambda" {
  name                 = "${var.project_name}/employee-service-lambda"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-employee-service-lambda"
  }
}

# Lambda Function (컨테이너 이미지)
resource "aws_lambda_function" "employee" {
  function_name = "${var.project_name}-${var.environment}-employee-service"
  role          = aws_iam_role.lambda.arn
  
  package_type = "Image"
  image_uri    = "${aws_ecr_repository.employee_lambda.repository_url}:latest"
  
  vpc_config {
    subnet_ids         = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      SPRING_DATASOURCE_URL = "jdbc:mysql://${data.terraform_remote_state.rds.outputs.endpoint}:3306/erp?useSSL=true"
    }
  }
  
  memory_size = 512
  timeout     = 30
  
  tags = {
    Name = "${var.project_name}-${var.environment}-employee-service"
  }
}

# Lambda Permission (API Gateway 호출 허용)
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.employee.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.terraform_remote_state.api_gateway.outputs.api_gateway_execution_arn}/*/*"
}

# API Gateway Integration (Lambda 직접 통합)
resource "aws_apigatewayv2_integration" "employee_lambda" {
  api_id             = data.terraform_remote_state.api_gateway.outputs.api_gateway_id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.employee.invoke_arn
  payload_format_version = "2.0"
}

# API Gateway Route (기존 NLB 라우트 대체)
resource "aws_apigatewayv2_route" "employee_proxy" {
  api_id    = data.terraform_remote_state.api_gateway.outputs.api_gateway_id
  route_key = "ANY /api/employees/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.employee_lambda.id}"
}

resource "aws_apigatewayv2_route" "employee_root" {
  api_id    = data.terraform_remote_state.api_gateway.outputs.api_gateway_id
  route_key = "ANY /api/employees"
  target    = "integrations/${aws_apigatewayv2_integration.employee_lambda.id}"
}
EOF
```

### 1-3. variables.tf 생성

```bash
cat > variables.tf << 'EOF'
variable "project_name" {
  default = "erp"
}

variable "environment" {
  default = "dev"
}

variable "region" {
  default = "ap-northeast-2"
}

variable "account_id" {
  default = "806332783810"
}
EOF
```

### 1-4. outputs.tf 생성

```bash
cat > outputs.tf << 'EOF'
output "lambda_function_arn" {
  value = aws_lambda_function.employee.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.employee.function_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.employee_lambda.repository_url
}
EOF
```

---

##  Step 2: Lambda용 Dockerfile 생성 (20분)

### 2-1. Dockerfile.lambda 생성

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/backend/employee-service

cat > Dockerfile.lambda << 'EOF'
FROM public.ecr.aws/lambda/java:17

# JAR 파일 복사
COPY target/employee-service-1.0.0.jar ${LAMBDA_TASK_ROOT}/app.jar

# Lambda Handler 설정
CMD ["org.springframework.cloud.function.adapter.aws.FunctionInvoker::handleRequest"]
EOF
```

### 2-2. pom.xml에 Lambda 의존성 추가

```bash
# pom.xml 수정
cat >> pom.xml << 'EOF'

<!-- Lambda 의존성 추가 -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-function-adapter-aws</artifactId>
    <version>4.0.0</version>
</dependency>
EOF
```

---

##  Step 3: Terraform 배포 (20분)

### 4-1. Terraform 초기화 및 배포

```bash
cd infrastructure/terraform/dev/erp-dev-Lambda

# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply -auto-approve
```

**생성 리소스:**
- Lambda Function (employee-service)
- Lambda IAM Role
- Lambda Security Group
- ECR Repository (employee-service-lambda)
- API Gateway Integration (Lambda 직접 통합)
- API Gateway Routes (/api/employees, /api/employees/{proxy+})

**확인:**
```bash
terraform output

# 예상 출력:
# lambda_function_arn = "arn:aws:lambda:ap-northeast-2:806332783810:function:erp-dev-employee-service"
# ecr_repository_url = "806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service-lambda"
```

---

##  Step 4: Lambda 이미지 빌드 및 배포 (20분)

### 5-1. Lambda 이미지 빌드

```bash
cd backend/employee-service

# Maven 빌드
mvn clean package -DskipTests

# Lambda용 Docker 이미지 빌드
docker build -f Dockerfile.lambda -t employee-service-lambda:latest .

# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 태그
docker tag employee-service-lambda:latest 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service-lambda:latest

# ECR 푸시
docker push 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service-lambda:latest
```

### 5-2. Lambda 함수 업데이트

```bash
# Lambda 함수 이미지 업데이트
aws lambda update-function-code \
  --function-name erp-dev-employee-service \
  --image-uri 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service-lambda:latest \
  --region ap-northeast-2

# 업데이트 완료 대기
aws lambda wait function-updated \
  --function-name erp-dev-employee-service \
  --region ap-northeast-2
```

---

##  Step 5: 검증 (10분)

### 6-1. Lambda 함수 확인

```bash
# Lambda 함수 상태 확인
aws lambda get-function \
  --function-name erp-dev-employee-service \
  --region ap-northeast-2 \
  --query 'Configuration.[FunctionName,State,LastUpdateStatus]' \
  --output table

# 예상 출력:
# --------------------------------
# |  GetFunction                 |
# +------------------------------+
# |  erp-dev-employee-service    |
# |  Active                      |
# |  Successful                  |
# +------------------------------+
```

### 6-2. API Gateway 테스트

```bash
# Employee Service 테스트 (Lambda 호출)
curl https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/api/employees

# 예상 출력:
# [
#   {
#     "id": 1,
#     "name": "홍길동",
#     "email": "hong@erp.com",
#     "department": "DEVELOPMENT"
#   },
#   ...
# ]
```

### 6-3. Lambda 로그 확인

```bash
# CloudWatch Logs 확인
aws logs tail /aws/lambda/erp-dev-employee-service \
  --follow \
  --region ap-northeast-2
```

### 6-4. EKS에서 Employee Service 제거 확인

```bash
# Employee Service Pod가 없어야 함
kubectl get pods -n erp-dev | grep employee

# 출력 없음 (정상)

# Service도 없어야 함
kubectl get svc -n erp-dev | grep employee

# 출력 없음 (정상)
```

---

##  완료 체크리스트

- [ ] Terraform Lambda 모듈 생성
- [ ] Dockerfile.lambda 생성
- [ ] pom.xml에 Lambda 의존성 추가
- [ ] Helm Chart에서 employee 제거
- [ ] Terraform apply 성공
- [ ] Lambda 이미지 빌드 및 푸시
- [ ] Lambda 함수 업데이트
- [ ] API Gateway 테스트 성공
- [ ] Lambda 로그 확인
- [ ] EKS에서 Employee Pod 제거 확인

---

##  다음 단계

**Lambda 전환 완료!**

**다음 파일을 읽으세요:**
→ **04_BUILDSPEC.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 04_BUILDSPEC.md
```

---

##  개선 효과

### Before (모두 EKS)

```
총 8 Pods:
- Employee: 2 Pods
- Approval Request: 2 Pods
- Approval Processing: 2 Pods
- Notification: 2 Pods

비용: $82.30/월
```

### After (Employee → Lambda)

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

### API Gateway 라우팅

```
API Gateway (단일 진입점)
  ├─ /api/employees/*     → Lambda (직접 통합) 
  ├─ /api/approvals/*     → VPC Link → NLB → EKS
  └─ /api/notifications/* → VPC Link → NLB → EKS
```

**장점:**
- VPC Link 불필요 (Lambda 직접 통합)
- Cold Start 300~500ms (첫 요청만)
- 자동 스케일링 (동시 실행 1000개)

---

##  주의사항

### Cold Start

**첫 요청:**
- 300~500ms (컨테이너 초기화)

**이후 요청:**
- 50~100ms (정상)

**해결:**
- Provisioned Concurrency (추가 비용)
- 또는 Cold Start 허용 (개발 환경)

### RDS 연결

**Lambda → RDS:**
- VPC 내부 통신
- Security Group 설정 필요
- Connection Pool 최적화 필요

---

**"Employee Service를 Lambda로 전환했습니다. 비용 21% 절감!"**
