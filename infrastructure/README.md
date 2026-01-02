# ERP Infrastructure (Terraform)

**IaC Tool**: Terraform 1.6+  
**Cloud Provider**: AWS  
**Region**: ap-northeast-2 (Seoul)  
**State Backend**: S3 + DynamoDB Lock  
**Last Updated**: 2025-12-30

---

## 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                    CloudFront (HTTPS)
                         │
                    S3 (Frontend)
                         │
                    API Gateway (HTTP API)
                         │
        ┌────────────────┼────────────────┐
        │                │                │
    Lambda          VPC Link          Cognito
  (Employee)            │           (Auth)
        │               │
        │          NLB (Private)
        │               │
        │    ┌──────────┼──────────┐
        │    │          │          │
        │  Port 8082  Port 8083  Port 8084
        │    │          │          │
        │    │          │          │
    ┌───┴────┴──────────┴──────────┴───┐
    │         EKS Cluster (1.31)        │
    │  ┌─────────────────────────────┐  │
    │  │  Service Node Group (2)     │  │
    │  │  - approval-request (2 Pod) │  │
    │  │  - approval-processing (2)  │  │
    │  │  - notification (2)         │  │
    │  └─────────────────────────────┘  │
    │  ┌─────────────────────────────┐  │
    │  │  Kafka Node Group (2)       │  │
    │  │  - kafka (2 Pod)            │  │
    │  │  - zookeeper (2 Pod)        │  │
    │  │  - Taint: workload=kafka    │  │
    │  └─────────────────────────────┘  │
    └───────────────┬───────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
    RDS MySQL   ElastiCache  MongoDB Atlas
    (Private)    (Private)    (External)
```

**핵심 특징:**
- Lambda + EKS 하이브리드 (Employee는 Lambda, 나머지는 EKS)
- 2개 Node Group (Service용 2개, Kafka 전용 2개 with Taint)
- NLB를 통한 VPC Link 연결
- Secrets Manager 통합 (RDS 자격증명)
- Parameter Store 통합 (buildspec.yml 변수)
- CloudWatch Alarms (ERROR 로그, Pod 재시작, Lambda 에러)

---

## Terraform 모듈 구조

### 설계 철학: 세분화 vs 통합 vs 단일

#### tfstate 파일이란?

Terraform은 실제 AWS 리소스 상태를 `terraform.tfstate` 파일에 저장합니다. 이 파일은:
- **현재 인프라 상태 기록**: 어떤 리소스가 생성되었는지, ID는 무엇인지
- **변경 감지**: 코드와 실제 상태를 비교하여 변경사항 파악
- **의존성 관리**: 리소스 간 참조 관계 저장

**문제점**: 여러 사람이 동시에 `terraform apply`를 실행하면 tfstate 파일이 충돌합니다.

**해결책**: 
1. **S3 Backend**: tfstate를 S3에 저장하여 공유
2. **DynamoDB Lock**: 동시 실행 방지 (한 명만 apply 가능)
3. **모듈별 tfstate 분리**: 각 모듈이 독립적인 tfstate 파일 보유

---

### 세분화 / 통합 / 단일 전략

#### 1️⃣ 세분화 (Granular) - 하위 폴더별 독립 실행

**구조:**
```
erp-dev-VPC/
├── vpc/                    # terraform apply 1 (독립 tfstate)
├── subnet/                 # terraform apply 2 (독립 tfstate)
└── route-table/            # terraform apply 3 (독립 tfstate)
```

**특징:**
- 각 하위 폴더가 독립적인 tfstate 파일 보유
- 변경 시 해당 폴더만 apply (다른 리소스 영향 없음)
- State Lock 충돌 최소화 (A가 vpc 수정 중에도 B는 subnet 수정 가능)

**적용 대상:**
- **VPC** (3개): vpc, subnet, route-table
- **SecurityGroups** (4개): alb-sg, eks-sg, rds-sg, elasticache-sg
- **Databases** (2개): rds, elasticache

**선택 이유:**
- 변경 빈도가 높음 (보안 그룹 규칙, RDS 파라미터 등)
- 독립적으로 수정 가능 (VPC는 그대로 두고 보안 그룹만 변경)
- 콘솔에서 급하게 수정 후 형상 맞추기 용이

**실무 조언 (멘토):**
> "보안그룹이나 RDS를 테라폼으로 관리하면 정책 1개만 달라져도 틀어져서 여러 부서가 함께하는 프로젝트에는 부적합. 폴더는 세분화하고 각 tfstate 파일을 따로 저장하는게, 콘솔 작업 후 형상 맞춰주기 좋음."

**형상 관리 예시:**
```bash
# 급하게 콘솔에서 RDS 파라미터 변경
# → Terraform 형상 맞추기
cd erp-dev-Databases/rds
terraform import aws_db_parameter_group.main erp-dev-mysql-params
terraform plan  # RDS만 확인 (다른 리소스 영향 없음)
terraform apply
```

---

#### 2️⃣ 통합 (Integrated) - main.tf에서 module 호출

**구조:**
```
erp-dev-IAM/
├── main.tf                 # 4개 모듈 호출 (한 번에 apply)
├── eks-cluster-role/
├── eks-node-role/
├── codebuild-role/
└── codepipeline-role/
```

**main.tf 예시:**
```hcl
module "eks_cluster_role" {
  source = "./eks-cluster-role"
}

module "eks_node_role" {
  source = "./eks-node-role"
}

# 한 번에 terraform apply
```

**특징:**
- main.tf가 하위 모듈을 호출하여 한 번에 apply
- 하나의 tfstate 파일에 모든 하위 리소스 저장
- 의존성 자동 관리 (eks-cluster-role → eks-node-role 순서)

**적용 대상:**
- **IAM** (4개 role): Trust Policy 일관성 필요
- **EKS** (3개 모듈): cluster → node-group 의존성
- **APIGateway** (2개 모듈): NLB + API Gateway 원자성
- **Frontend** (2개 모듈): S3 + CloudFront 연동
- **Cognito** (1개 모듈): user-pool
- **CICD** (3개 모듈): s3-artifacts, codebuild, codepipeline

**선택 이유:**
- 강한 의존성 (IAM Trust Policy, EKS Cluster → Node Group)
- 원자성 보장 (NLB + API Gateway는 함께 생성/삭제)
- 초기 구축 시 한 번에 실행 편리

---

#### 3️⃣ 단일 (Single) - 폴더 바로 아래 tf 파일

**구조:**
```
erp-dev-ECR/
├── ecr.tf                  # 4개 Repository 정의
├── outputs.tf
└── variables.tf
```

**특징:**
- 하위 모듈 없이 단일 tf 파일
- 가장 간단한 구조

**적용 대상:**
- **ECR** (4개 Repository)
- **Lambda** (employee-service)
- **LoadBalancerController** (Helm)
- **ParameterStore** (6개 Parameter)
- **CloudWatch** (SNS + 3개 Alarm)

**선택 이유:**
- 독립적인 리소스 (다른 리소스와 의존성 없음)
- 변경 빈도 낮음
- 하위 모듈로 나눌 필요 없음

---

### 실무 vs 개인 프로젝트 차이

#### 실무 (멘토 조언)

**Terraform 사용 범위:**
- ✅ VPC 인프라 (VPC, Subnet, Route Table, NAT Gateway)
- ✅ 가벼운 리소스 (ECR, DB Subnet Group)
- ❌ 보안 그룹 (정책 1개만 달라져도 틀어짐)
- ❌ RDS (파라미터 1개만 달라져도 틀어짐)
- ❌ 자주 변경되는 리소스 (콘솔로 관리)

**이유:**
- 여러 부서/사람이 협업 시 State Lock 충돌
- 급한 변경은 콘솔로 처리 (Terraform 형상 맞추기 어려움)
- 변경 빈도 높은 리소스는 Terraform 부적합

#### 개인 프로젝트 (이 프로젝트)

**Terraform 사용 범위:**
- ✅ 모든 AWS 리소스 (VPC, SecurityGroups, RDS, EKS, Lambda 등)
- ✅ 14개 모듈로 완전 자동화

**이유:**
- 1인 개발로 State Lock 충돌 없음
- 학습 목적 (Terraform 전체 경험)
- 환경 재구축 용이 (terraform apply 한 번에 전체 인프라 생성)

**만약 협업이었다면:**
- VPC, Subnet, ECR만 Terraform
- SecurityGroups, RDS, EKS는 콘솔 관리
- 세분화 전략으로 각 팀이 독립적으로 작업

---

### 협업 시 형상 관리 이점

#### 시나리오: 보안팀이 급하게 보안 그룹 수정

**세분화 구조 (이 프로젝트):**
```bash
# 1. 콘솔에서 급하게 수정
AWS Console → SecurityGroups → eks-sg → 규칙 추가

# 2. Terraform 형상 맞추기
cd erp-dev-SecurityGroups/eks-sg
terraform plan  # eks-sg만 확인 (다른 SG 영향 없음)
terraform apply  # 20초 소요

# 3. 다른 팀은 계속 작업 가능
cd erp-dev-Databases/rds
terraform apply  # State Lock 충돌 없음
```

**통합 구조 (만약 모든 SG를 하나로):**
```bash
# 1. 콘솔에서 급하게 수정
AWS Console → SecurityGroups → eks-sg → 규칙 추가

# 2. Terraform 형상 맞추기
cd erp-dev-SecurityGroups
terraform plan  # 모든 SG 확인 (alb-sg, eks-sg, rds-sg, elasticache-sg)
terraform apply  # 2분 소요

# 3. 다른 팀은 대기 필요
cd erp-dev-Databases/rds
terraform apply  # State Lock 충돌! (SecurityGroups apply 중)
```

**결론:**
- 세분화 구조는 변경 영향 최소화
- 각 팀이 독립적으로 작업 가능
- State Lock 충돌 최소화

---

### 폴더 구조 (최종)

```
infrastructure/terraform/dev/
├── erp-dev-VPC/                    # 세분화 (3개 하위 모듈)
│   ├── main.tf                     # 없음 (각각 독립 apply)
│   ├── vpc/                        # VPC + IGW
│   ├── subnet/                     # Public/Private/Data Subnet + NAT
│   └── route-table/                # Route Table + Association
│
├── erp-dev-SecurityGroups/         # 세분화 (4개 하위 모듈)
│   ├── main.tf                     # 없음 (각각 독립 apply)
│   ├── alb-sg/                     # ALB Security Group
│   ├── eks-sg/                     # EKS Node Security Group
│   ├── rds-sg/                     # RDS Security Group
│   └── elasticache-sg/             # ElastiCache Security Group
│
├── erp-dev-IAM/                    # 통합 (4개 하위 모듈)
│   ├── main.tf                     # 모듈 호출 (한 번에 apply)
│   ├── eks-cluster-role/           # EKS Cluster IAM Role
│   ├── eks-node-role/              # EKS Node IAM Role + Secrets/Logs 권한
│   ├── codebuild-role/             # CodeBuild IAM Role + 8개 Policy
│   └── codepipeline-role/          # CodePipeline IAM Role
│
├── erp-dev-Databases/              # 세분화 (2개 하위 모듈)
│   ├── main.tf                     # 없음 (각각 독립 apply)
│   ├── rds/                        # RDS MySQL + Secrets Manager 통합
│   └── elasticache/                # ElastiCache Redis
│
├── erp-dev-EKS/                    # 통합 (3개 하위 모듈)
│   ├── main.tf                     # 모듈 호출 (한 번에 apply)
│   ├── eks-cluster/                # EKS Cluster + OIDC Provider
│   ├── eks-node-group/             # 2개 Node Group (Service + Kafka)
│   └── eks-cluster-sg-rules/       # Cluster SG 추가 규칙 (EKS 생성 후)
│
├── erp-dev-ECR/                    # 단일
│   ├── ecr.tf                      # 4개 Repository (1 Lambda + 3 EKS)
│   ├── outputs.tf
│   └── variables.tf
│
├── erp-dev-LoadBalancerController/ # 단일
│   ├── load-balancer-controller.tf # Helm Release + IAM + ServiceAccount
│   ├── outputs.tf
│   └── variables.tf
│
├── erp-dev-Lambda/                 # 단일
│   ├── lambda.tf                   # Lambda + IAM + SG + API Gateway Routes
│   ├── outputs.tf
│   ├── provider.tf
│   └── variables.tf
│
├── erp-dev-APIGateway/             # 통합 (2개 하위 모듈)
│   ├── main.tf                     # 모듈 호출 (한 번에 apply)
│   ├── nlb/                        # NLB + 4개 Target Group + Listener
│   └── api-gateway/                # API Gateway + VPC Link + Routes
│
├── erp-dev-Frontend/               # 통합 (2개 하위 모듈)
│   ├── main.tf                     # 모듈 호출 (한 번에 apply)
│   ├── s3/                         # S3 Bucket + Website Hosting
│   └── cloudfront/                 # CloudFront Distribution
│
├── erp-dev-Cognito/                # 통합 (2개 하위 모듈)
│   ├── main.tf                     # 모듈 호출 (한 번에 apply)
│   ├── user-pool/                  # User Pool + Client + Lambda Trigger
│   └── identity-pool/              # Identity Pool (미사용)
│
├── erp-dev-ParameterStore/         # 단일
│   ├── parameter-store.tf          # 6개 Parameter (buildspec.yml용)
│   ├── outputs.tf
│   └── variables.tf
│
├── erp-dev-CloudWatch/             # 단일
│   ├── cloudwatch-alarms.tf        # SNS + Metric Filter + 3개 Alarm
│   ├── outputs.tf
│   └── variables.tf
│
└── erp-dev-CICD/                   # 통합 (3개 하위 모듈)
    ├── main.tf                     # 모듈 호출 (한 번에 apply)
    ├── s3-artifacts/               # S3 Bucket (Artifacts)
    ├── codebuild/                  # CodeBuild Project
    └── codepipeline/               # CodePipeline (Source + Build)
```

---

## 세분화 전략 상세

### 왜 세분화했는가?

**예시: erp-dev-SecurityGroups (4개 하위 모듈)**

```bash
# 각각 독립적으로 apply
cd erp-dev-SecurityGroups/alb-sg && terraform apply
cd ../eks-sg && terraform apply
cd ../rds-sg && terraform apply
cd ../elasticache-sg && terraform apply
```

**장점:**
1. 독립적인 생명주기: RDS SG 변경 시 EKS SG 영향 없음
2. State Lock 충돌 방지: 4개 독립 tfstate → 팀원 A가 RDS SG 수정 중, 팀원 B는 EKS SG 수정 가능
3. 빠른 Plan/Apply: 전체 SG 약 2분 → 개별 SG 약 20초 (10배 빠름)
4. 콘솔 작업 후 형상 관리 용이: 급하게 콘솔에서 포트 추가 → 해당 폴더만 terraform plan으로 확인

**단점:**
- 초기 구축 시 4번 실행 필요
- 의존성 관리 필요 (remote state 사용)

---

## 통합 전략 상세

### 왜 통합했는가?

**예시: erp-dev-IAM (4개 하위 모듈)**

```bash
# main.tf가 모든 하위 모듈 호출
cd erp-dev-IAM && terraform apply
```

```hcl
# main.tf
module "eks_cluster_role" { source = "./eks-cluster-role" }
module "eks_node_role" { source = "./eks-node-role" }
module "codebuild_role" { source = "./codebuild-role" }
module "codepipeline_role" { source = "./codepipeline-role" }
```

**장점:**
1. 강한 의존성: EKS Cluster Role과 Node Role은 함께 생성되어야 함
2. 상호 참조: CodeBuild Role과 CodePipeline Role은 서로 참조
3. 원자성: 모든 Role이 함께 생성되거나 함께 실패
4. 간단한 실행: 한 번의 apply로 모든 리소스 생성

**단점:**
- 한 Role 변경 시 전체 Plan 필요 (하지만 실제 변경은 해당 Role만)

---

## 단일 구조 상세

### 왜 단일 구조인가?

**예시: erp-dev-ECR (단일 파일)**

```hcl
# ecr.tf
resource "aws_ecr_repository" "employee_lambda" {
  name = "erp/employee-service-lambda"
}

resource "aws_ecr_repository" "eks_services" {
  for_each = toset(["approval-request-service", "approval-processing-service", "notification-service"])
  name     = "erp/${each.key}"
}
```

**이유:**
1. 간단한 리소스: ECR Repository 4개만 생성
2. 강한 연관성: 모두 같은 프로젝트의 컨테이너 이미지 저장소
3. 동시 생성 필요: 모든 Repository가 함께 생성되어야 함
4. 하위 모듈 불필요: 복잡도가 낮아서 분리할 필요 없음

**적용 모듈:**
- ECR: 4개 Repository
- LoadBalancerController: Helm Release + IAM + ServiceAccount
- Lambda: Lambda Function + IAM + SG + API Gateway Routes
- ParameterStore: 6개 Parameter
- CloudWatch: SNS + Metric Filter + 3개 Alarm

---

## 배포 순서 (의존성 기반)

### 의존성 그래프

```
VPC → SecurityGroups → IAM → Databases → EKS → ECR → LoadBalancerController → Lambda → APIGateway → Frontend → Cognito → ParameterStore → CloudWatch → CICD
```

### 상세 배포 순서

```bash
cd infrastructure/terraform/dev

# 1. VPC (세분화, 15분)
cd erp-dev-VPC/vpc && terraform init && terraform apply -auto-approve
cd ../subnet && terraform init && terraform apply -auto-approve
cd ../route-table && terraform init && terraform apply -auto-approve

# 2. Security Groups (세분화, 10분)
cd ../../erp-dev-SecurityGroups/alb-sg && terraform init && terraform apply -auto-approve
cd ../eks-sg && terraform init && terraform apply -auto-approve  # EKS 생성 전이라 일부 실패 예상
cd ../rds-sg && terraform init && terraform apply -auto-approve
cd ../elasticache-sg && terraform init && terraform apply -auto-approve

# 3. IAM (통합, 5분)
cd ../../erp-dev-IAM && terraform init && terraform apply -auto-approve

# 4. Databases (세분화, 20분)
cd ../erp-dev-Databases/rds && terraform init && terraform apply -auto-approve  # 10분 대기
cd ../elasticache && terraform init && terraform apply -auto-approve  # 5분 대기

# 5. EKS (통합, 30분)
cd ../../erp-dev-EKS && terraform init && terraform apply -auto-approve  # 15분 대기

# 5.5. EKS Cluster SG 추가 규칙 (EKS 생성 후)
cd ../erp-dev-SecurityGroups/eks-sg && terraform apply -auto-approve  # 이제 성공

# 6. ECR (단일, 5분)
cd ../../erp-dev-ECR && terraform init && terraform apply -auto-approve

# 7. Load Balancer Controller (단일, 10분)
cd ../erp-dev-LoadBalancerController && terraform init && terraform apply -auto-approve

# 8. Lambda (단일, 10분)
cd ../erp-dev-Lambda && terraform init && terraform apply -auto-approve

# 9. API Gateway (통합, 15분)
cd ../erp-dev-APIGateway && terraform init && terraform apply -auto-approve

# 10. Frontend (통합, 10분)
cd ../erp-dev-Frontend && terraform init && terraform apply -auto-approve

# 11. Cognito (통합, 5분)
cd ../erp-dev-Cognito && terraform init && terraform apply -auto-approve

# 12. Parameter Store (단일, 5분)
cd ../erp-dev-ParameterStore && terraform init && terraform apply -auto-approve

# 13. CloudWatch (단일, 5분)
cd ../erp-dev-CloudWatch && terraform init && terraform apply -auto-approve
# ⚠️ 이메일 확인 필수: subinhong0109@dankook.ac.kr에서 SNS 구독 확인

# 14. CI/CD (통합, 5분)
cd ../erp-dev-CICD && terraform init && terraform apply -auto-approve
```

**총 소요 시간: 약 2시간**

---

## 주요 리소스 상세

### 1. VPC (10.0.0.0/16)

**구조:**
- Public Subnet: 10.0.1.0/24, 10.0.2.0/24 (AZ-A, AZ-C)
- Private Subnet: 10.0.10.0/24, 10.0.11.0/24 (AZ-A, AZ-C)
- Data Subnet: 10.0.20.0/24, 10.0.21.0/24 (AZ-A, AZ-C)
- NAT Gateway: 1개 (Public Subnet 1)
- Internet Gateway: 1개

**태그:**
- Public Subnet: `kubernetes.io/role/elb=1` (ALB용)
- Private Subnet: `kubernetes.io/role/internal-elb=1` (NLB용)

### 2. Security Groups

**alb-sg:**
- Ingress: 80, 443 from 0.0.0.0/0
- Egress: All

**eks-sg:**
- Ingress: 8081-8084 from alb-sg (Application Ports)
- Ingress: All from self (Cluster 내부 통신)
- Egress: All

**rds-sg:**
- Ingress: 3306 from eks-sg
- Egress: All

**elasticache-sg:**
- Ingress: 6379 from eks-sg (EKS Node SG)
- Ingress: 6379 from EKS Cluster SG (자동 생성된 SG)
- Egress: All

**이유:** EKS Node가 실제로 Cluster SG를 사용하기 때문에 2개 모두 허용

### 3. IAM Roles

**eks-cluster-role:**
- AmazonEKSClusterPolicy
- AmazonEKSVPCResourceController

**eks-node-role:**
- AmazonEKSWorkerNodePolicy
- AmazonEKS_CNI_Policy
- AmazonEC2ContainerRegistryReadOnly
- AmazonSSMManagedInstanceCore
- Custom: Secrets Manager 읽기 (erp/*)
- Custom: CloudWatch Logs 쓰기 (/aws/eks/erp-dev/*)

**codebuild-role:**
- ECR: GetAuthorizationToken, Push/Pull
- EKS: DescribeCluster
- Logs: CreateLogGroup, PutLogEvents
- S3: GetObject, PutObject
- Secrets Manager: GetSecretValue (buildspec.yml용)
- Parameter Store: GetParameter (buildspec.yml용)
- ECR: StartImageScan (보안 스캔)
- CodeConnections: UseConnection (GitHub 연결)

**codepipeline-role:**
- S3: GetObject, PutObject
- CodeBuild: StartBuild, BatchGetBuilds
- CodeConnections: UseConnection

### 4. Databases

**RDS MySQL:**
- Engine: MySQL 8.0
- Instance: db.t3.micro
- Storage: 20GB gp3
- Multi-AZ: false (개발 환경)
- Backup: 1일
- Secrets Manager 통합: `erp/dev/mysql`에서 자격증명 읽기

**ElastiCache Redis:**
- Engine: Redis 7.0
- Node: cache.t3.micro
- Nodes: 1개
- Parameter Group: default.redis7

### 5. EKS (1.31)

**Cluster:**
- Version: 1.31
- Endpoint: Private + Public
- OIDC Provider: 자동 생성 (IRSA용)

**Node Group 1 (Service):**
- Instance: t3.small
- Desired: 2, Min: 1, Max: 3
- Disk: 20GB gp3 encrypted
- Labels: 없음
- Taints: 없음
- 용도: approval-request, approval-processing, notification

**Node Group 2 (Kafka):**
- Instance: t3.small
- Desired: 2, Min: 2, Max: 2
- Disk: 20GB gp3 encrypted
- Labels: `workload=kafka`
- Taints: `workload=kafka:NoSchedule`
- 용도: kafka, zookeeper

**격리 메커니즘:**
- Service Pod: Taint 때문에 Kafka Node 접근 불가
- Kafka Pod: nodeSelector + Toleration으로 Kafka Node로만 배치
- Anti-Affinity: 같은 서비스 Pod는 다른 AZ에 배치

### 6. ECR

**Repositories:**
- erp/employee-service-lambda (Lambda용)
- erp/approval-request-service (EKS용)
- erp/approval-processing-service (EKS용)
- erp/notification-service (EKS용)

**설정:**
- Image Scanning: Enabled (Push 시 자동 스캔)
- Tag Mutability: MUTABLE

### 7. Load Balancer Controller

**구성:**
- Helm Chart: aws-load-balancer-controller 1.7.0
- IAM Role: IRSA (IAM Roles for Service Accounts)
- ServiceAccount: aws-load-balancer-controller
- Namespace: kube-system

**역할:**
- TargetGroupBinding 처리 (Pod IP를 NLB Target Group에 자동 등록)

### 8. Lambda (Employee Service)

**구성:**
- Function: erp-dev-employee-service
- Package: Image (ECR)
- Memory: 2048MB
- Timeout: 60s
- VPC: Private Subnet
- Environment Variables: RDS 자격증명 (Secrets Manager에서 읽기)

**API Gateway 통합:**
- Integration Type: AWS_PROXY (Lambda 직접 통합, VPC Link 불필요)
- Routes: /api/employees, /api/employees/{proxy+}, /api/quests, /api/quests/{proxy+}, /api/attendance, /api/attendance/{proxy+}, /api/leaves, /api/leaves/{proxy+}

### 9. API Gateway

**NLB (Private):**
- Type: Network Load Balancer
- Scheme: Internal
- Target Groups: 4개 (employee:8081, approval-request:8082, approval-processing:8083, notification:8084)
- Target Type: IP (TargetGroupBinding이 Pod IP 등록)
- Health Check: TCP

**API Gateway (HTTP API):**
- Protocol: HTTP
- CORS: Enabled (모든 Origin 허용)
- VPC Link: NLB 연결
- Routes: 7개 (employees, approvals, process, notifications, attendance, quests, leaves)
- Logging: CloudWatch Logs (/aws/apigateway/erp-dev-api)

**Integration:**
- Lambda: AWS_PROXY (직접 통합)
- EKS: HTTP_PROXY (VPC Link → NLB)

### 10. Frontend

**S3:**
- Bucket: erp-dev-frontend-dev
- Website Hosting: Enabled
- Public Access: Enabled
- Policy: PublicReadGetObject

**CloudFront:**
- Origin: S3 Website Endpoint
- Protocol: Redirect to HTTPS
- Cache: 1시간 (default_ttl)
- Error Pages: 404, 403 → /index.html (SPA 라우팅)

### 11. Cognito

**User Pool:**
- Username: Email
- Password: 최소 6자 (개발 환경)
- Custom Attributes: position, department, employeeId
- Lambda Trigger: Pre Sign-up (자동 확인)

**App Client:**
- Auth Flows: USER_PASSWORD_AUTH, REFRESH_TOKEN_AUTH, USER_SRP_AUTH
- Token Validity: Access 60분, ID 60분, Refresh 30일

### 12. Parameter Store

**Parameters (buildspec.yml용):**
- /erp/dev/account-id: AWS Account ID
- /erp/dev/region: ap-northeast-2
- /erp/dev/eks/cluster-name: erp-dev
- /erp/dev/ecr/repository-prefix: erp
- /erp/dev/project-name: erp
- /erp/dev/environment: dev

**용도:** buildspec.yml에서 하드코딩 제거

### 13. CloudWatch

**SNS Topic:**
- Name: erp-dev-alarms
- Subscription: subinhong0109@dankook.ac.kr (이메일 확인 필수)

**Metric Filters:**
- ERROR 로그 카운트 (Pattern: "ERROR")
- Pod 재시작 감지 (Pattern: "restart|killed|crash|OOMKilled|CrashLoopBackOff")

**Alarms:**
- high-error-rate: ERROR 로그 5분 동안 10회 이상
- pod-restarts: Pod 재시작 10분 동안 3회 이상
- lambda-error-rate: Lambda 에러율 5% 이상

### 14. CI/CD

**S3 Artifacts:**
- Bucket: codepipeline-ap-northeast-2-806332783810
- Versioning: Enabled

**CodeBuild:**
- Project: erp-unified-build
- Image: aws/codebuild/standard:7.0
- Compute: BUILD_GENERAL1_SMALL
- Buildspec: buildspec.yml (루트)
- Logs: /aws/codebuild/erp-unified-build

**CodePipeline:**
- Pipeline: erp-unified-pipeline
- Source: GitHub (CodeStar Connection)
- Build: CodeBuild
- Stages: Source → Build

---

## 비용 분석

**월 예상 비용: $206**

| 리소스 | 사양 | 비용 |
|--------|------|------|
| EKS Cluster | 1개 | $73 |
| EKS Nodes | t3.small × 4 | $60 |
| RDS MySQL | db.t3.micro | $15 |
| ElastiCache | cache.t3.micro | $12 |
| NAT Gateway | 1개 | $32 |
| NLB | 1개 | $16 |
| Lambda | 2048MB, 저사용 | $3 |
| CloudFront | 저사용 | $1 |
| S3 | 저사용 | $1 |
| 기타 | ECR, Logs 등 | $3 |

**비용 절감 방안:**
- NAT Gateway 제거 (VPC Endpoint 사용): -$32
- EKS Node 2개로 감소 (Kafka 제거): -$30
- RDS 중지 (개발 시간 외): -$10

---

## Remote State 구조

**S3 Backend:**
- Bucket: erp-terraform-state-subin-bucket
- DynamoDB Table: erp-terraform-locks
- Encryption: Enabled

**State 파일 경로:**
```
s3://erp-terraform-state-subin-bucket/
├── dev/
│   ├── vpc/
│   │   ├── vpc/terraform.tfstate
│   │   ├── subnet/terraform.tfstate
│   │   └── route-table/terraform.tfstate
│   ├── security-groups/
│   │   ├── alb-sg/terraform.tfstate
│   │   ├── eks-sg/terraform.tfstate
│   │   ├── rds-sg/terraform.tfstate
│   │   └── elasticache-sg/terraform.tfstate
│   ├── iam/terraform.tfstate
│   ├── databases/
│   │   ├── rds/terraform.tfstate
│   │   └── elasticache/terraform.tfstate
│   ├── eks/terraform.tfstate
│   ├── ecr/terraform.tfstate
│   ├── load-balancer-controller/terraform.tfstate
│   ├── lambda/terraform.tfstate
│   ├── api-gateway/terraform.tfstate
│   ├── frontend/terraform.tfstate
│   ├── cognito/terraform.tfstate
│   ├── parameter-store/terraform.tfstate
│   ├── cloudwatch/terraform.tfstate
│   └── cicd/terraform.tfstate
```

**Remote State 참조 예시:**
```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-subin-bucket"
    key    = "dev/vpc/vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 사용
vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
```

---

## 트러블슈팅

### 1. Terraform State Lock

**증상:**
```
Error: Error acquiring the state lock
Lock Info:
  ID: xxx
  Path: erp-terraform-state-subin-bucket/dev/xxx/terraform.tfstate
```

**원인:** 이전 terraform 실행이 비정상 종료되어 Lock이 남아있음

**해결:**
```bash
terraform force-unlock <LOCK_ID>
```

### 2. EKS Security Group 규칙 실패

**증상:**
```
Error: data.aws_eks_cluster.main: cluster "erp-dev" not found
```

**원인:** EKS Cluster가 아직 생성되지 않았는데 Cluster SG를 참조하려고 함

**해결:**
1. EKS Cluster 먼저 생성
2. 이후 `erp-dev-SecurityGroups/eks-sg` 다시 apply

### 3. Lambda Cold Start

**증상:** 첫 요청이 느림 (5-10초)

**원인:** Lambda가 VPC 내부에 있어서 ENI 생성 시간 필요

**해결:**
- Provisioned Concurrency 사용 (비용 증가)
- 또는 Cold Start 허용 (개발 환경)

### 4. NLB Health Check 실패

**증상:** Target Group에 Pod IP가 등록되지 않음

**원인:**
- TargetGroupBinding이 없음
- Pod가 Ready 상태가 아님
- Security Group 규칙 누락

**해결:**
```bash
# TargetGroupBinding 확인
kubectl get targetgroupbinding -n erp-dev

# Pod 상태 확인
kubectl get pods -n erp-dev

# Target Group 확인
aws elbv2 describe-target-health --target-group-arn <arn>
```

### 5. CloudWatch Alarm 이메일 안 옴

**증상:** Alarm이 발생해도 이메일이 안 옴

**원인:** SNS 구독 확인 안 함

**해결:**
1. subinhong0109@dankook.ac.kr 이메일 확인
2. "AWS Notification - Subscription Confirmation" 이메일 열기
3. "Confirm subscription" 링크 클릭

### 6. CodePipeline 실패

**증상:** Source 단계에서 실패

**원인:** GitHub CodeStar Connection이 Pending 상태

**해결:**
```bash
# Connection 상태 확인
aws codeconnections list-connections --region ap-northeast-2

# AWS Console에서 Connection 승인 필요
```

### 7. Secrets Manager 권한 오류

**증상:** Lambda 또는 EKS Pod에서 Secrets Manager 읽기 실패

**원인:** IAM Role에 Secrets Manager 권한 없음

**해결:**
- Lambda: `lambda-secrets-policy` 확인
- EKS: `eks-node-secrets-manager-policy` 확인

---

## 모니터링

### Terraform State 확인

```bash
# 모든 리소스 목록
terraform state list

# 특정 리소스 상세
terraform state show aws_eks_cluster.main

# State 파일 위치
aws s3 ls s3://erp-terraform-state-subin-bucket/dev/ --recursive
```

### AWS 리소스 확인

```bash
# VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=erp-dev-vpc" --region ap-northeast-2

# EKS
aws eks describe-cluster --name erp-dev --region ap-northeast-2

# RDS
aws rds describe-db-instances --db-instance-identifier erp-dev-mysql --region ap-northeast-2

# Lambda
aws lambda get-function --function-name erp-dev-employee-service --region ap-northeast-2

# NLB
aws elbv2 describe-load-balancers --names erp-dev-nlb --region ap-northeast-2

# API Gateway
aws apigatewayv2 get-apis --region ap-northeast-2 | grep erp-dev
```

### 비용 확인

```bash
# 현재 월 비용
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --region us-east-1

# 서비스별 비용
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1
```

---

## 리소스 삭제

**주의:** 역순으로 삭제해야 의존성 오류 방지

```bash
cd infrastructure/terraform/dev

# 14. CI/CD
cd erp-dev-CICD && terraform destroy -auto-approve

# 13. CloudWatch
cd ../erp-dev-CloudWatch && terraform destroy -auto-approve

# 12. Parameter Store
cd ../erp-dev-ParameterStore && terraform destroy -auto-approve

# 11. Cognito
cd ../erp-dev-Cognito && terraform destroy -auto-approve

# 10. Frontend
cd ../erp-dev-Frontend && terraform destroy -auto-approve

# 9. API Gateway
cd ../erp-dev-APIGateway && terraform destroy -auto-approve

# 8. Lambda
cd ../erp-dev-Lambda && terraform destroy -auto-approve

# 7. Load Balancer Controller
cd ../erp-dev-LoadBalancerController && terraform destroy -auto-approve

# 6. ECR (이미지 먼저 삭제 필요)
aws ecr batch-delete-image --repository-name erp/employee-service-lambda --image-ids imageTag=latest --region ap-northeast-2
aws ecr batch-delete-image --repository-name erp/approval-request-service --image-ids imageTag=latest --region ap-northeast-2
aws ecr batch-delete-image --repository-name erp/approval-processing-service --image-ids imageTag=latest --region ap-northeast-2
aws ecr batch-delete-image --repository-name erp/notification-service --image-ids imageTag=latest --region ap-northeast-2
cd ../erp-dev-ECR && terraform destroy -auto-approve

# 5. EKS (Pod 먼저 삭제 필요)
kubectl delete all --all -n erp-dev
cd ../erp-dev-EKS && terraform destroy -auto-approve

# 4. Databases
cd ../erp-dev-Databases/elasticache && terraform destroy -auto-approve
cd ../rds && terraform destroy -auto-approve

# 3. IAM
cd ../../erp-dev-IAM && terraform destroy -auto-approve

# 2. Security Groups
cd ../erp-dev-SecurityGroups/elasticache-sg && terraform destroy -auto-approve
cd ../rds-sg && terraform destroy -auto-approve
cd ../eks-sg && terraform destroy -auto-approve
cd ../alb-sg && terraform destroy -auto-approve

# 1. VPC
cd ../../erp-dev-VPC/route-table && terraform destroy -auto-approve
cd ../subnet && terraform destroy -auto-approve
cd ../vpc && terraform destroy -auto-approve
```

---

## 실시간 알림 구현 (WebSocket vs Polling)

### 현재 구현: Polling 방식

**구조:**
```
프론트엔드 → 5초마다 HTTP GET → API Gateway → notification-service
```

**코드:**
```javascript
// frontend/src/services/notificationService.js
setInterval(async () => {
  const response = await axios.get(`/notifications/recent/${employeeId}`);
  // 알림 표시
}, 5000);
```

**장점:**
- 구현 단순 (HTTP만 사용)
- 인프라 복잡도 낮음
- 디버깅 쉬움
- 비용 저렴

**단점:**
- 실시간성 낮음 (최대 5초 지연)
- 불필요한 요청 발생 (알림 없어도 5초마다 요청)

---

### WebSocket 구현 시도 및 실패

#### 문제 1: HTTPS → WS 연결 차단
```
CloudFront(HTTPS) → notification-service(WS)
❌ 브라우저 보안 정책: HTTPS 페이지에서 WS(비암호화) 연결 차단
```

#### 해결 시도: API Gateway WebSocket API
```
CloudFront(HTTPS) → API Gateway(WSS) → NLB → notification-service(HTTP)
```

**Terraform 코드:**
```hcl
resource "aws_apigatewayv2_api" "websocket" {
  name                       = "erp-dev-websocket"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_integration" "websocket" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "HTTP_PROXY"
  integration_uri  = "http://${var.nlb_dns_name}:8084"
}
```

**배포 결과:**
- WebSocket URL: `wss://orqk1dg957.execute-api.ap-northeast-2.amazonaws.com/dev`
- 연결 성공

#### 문제 2: STOMP 프로토콜 불일치

**Spring WebSocket 기대:**
```
CONNECT
accept-version:1.2
host:example.com

SUBSCRIBE
id:sub-0
destination:/topic/notifications
```

**API Gateway 전달:**
```json
{
  "requestContext": {...},
  "body": "CONNECT\naccept-version:1.2\n\n"  // 단순 문자열
}
```

**결과:**
- API Gateway는 WebSocket 연결만 중계
- STOMP 프레임 구조를 이해하지 못함
- Spring이 STOMP 핸들러를 찾지 못해 연결 실패

---

### 프로덕션 환경 해결 방법

#### 방법 1: NLB + Spring WebSocket 직접 노출 (권장)
```
Client → ALB(HTTPS) → NLB(TCP) → Spring WebSocket
```

**장점:**
- STOMP 프로토콜 그대로 사용
- API Gateway 없이 직접 연결
- 가장 일반적인 실전 구성

**단점:**
- ACM 인증서 설정 필요
- NLB 비용 추가 ($16/월)

**구현:**
```hcl
resource "aws_lb" "websocket" {
  name               = "erp-dev-websocket-nlb"
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids
}

resource "aws_lb_listener" "websocket" {
  load_balancer_arn = aws_lb.websocket.arn
  port              = "443"
  protocol          = "TLS"
  certificate_arn   = var.acm_certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.websocket.arn
  }
}
```

#### 방법 2: API Gateway WebSocket + Lambda (서버리스)
```
Client → API Gateway WebSocket → Lambda → DynamoDB (연결 관리)
```

**장점:**
- 서버리스 아키텍처
- 자동 스케일링
- 연결당 과금 (유휴 시 비용 없음)

**단점:**
- Spring WebSocket 코드 전면 수정 필요
- Lambda로 메시지 라우팅 직접 구현
- 복잡도 증가

**구현:**
```javascript
// Lambda: $connect
exports.handler = async (event) => {
  const connectionId = event.requestContext.connectionId;
  await dynamodb.put({
    TableName: 'WebSocketConnections',
    Item: { connectionId, employeeId }
  });
};

// Lambda: sendMessage
const connections = await dynamodb.query({ employeeId });
for (const conn of connections) {
  await apigateway.postToConnection({
    ConnectionId: conn.connectionId,
    Data: JSON.stringify(message)
  });
}
```

#### 방법 3: 관리형 서비스 (대규모)
```
- AWS AppSync (GraphQL Subscriptions)
- AWS IoT Core (MQTT)
- Pusher, Ably 같은 SaaS
```

**장점:**
- 수십만 동시접속 지원
- 인프라 관리 불필요
- 고가용성 보장

**단점:**
- 비용 높음
- 벤더 종속

---

### 현업 선택 기준

| 요구사항 | 선택 |
|---------|------|
| 알림이 1분 이내 도착하면 OK | **Polling** (현재 방식) |
| 채팅, 실시간 협업 필요 | **NLB + Spring WebSocket** |
| 동시접속 10만+ | **관리형 서비스** |
| 서버 관리 싫음 | **API Gateway + Lambda** |

**결재 시스템 권장:**
- 폴링으로 충분 (5초 지연 허용)
- WebSocket 인프라 관리 부담 > 실시간성 이점
- 비용 효율적 (추가 인프라 불필요)

---

### 현재 구현 상태

**배포된 리소스:**
- API Gateway WebSocket API: `wss://orqk1dg957.execute-api.ap-northeast-2.amazonaws.com/dev`
- 상태: 생성됨, 사용 안 함 (STOMP 불일치로 폴링 사용 중)

**프론트엔드:**
- notificationService.js: 5초 폴링 구현
- WebSocket 코드: 주석 처리

**향후 개선 시:**
1. NLB + Spring WebSocket 직접 노출
2. ACM 인증서 발급 (도메인 필요)
3. ALB → NLB 라우팅 설정
4. 프론트엔드 WebSocket 코드 활성화

---

## 참고 문서

**Terraform:**
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Backend S3](https://www.terraform.io/docs/language/settings/backends/s3.html)

**AWS:**
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Lambda in VPC](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html)
- [API Gateway VPC Link](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vpc-links.html)

**프로젝트 문서:**
- [02_TERRAFORM.md](../re_build/02_TERRAFORM.md): 상세 배포 가이드
- [Helm Chart README](../helm-chart/README.md): Kubernetes 배포 가이드

---

## 라이선스

MIT License
