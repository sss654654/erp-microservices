# Infrastructure

Terraform으로 관리되는 AWS 인프라입니다.

## 구조

9개 폴더로 세분화하여 독립 배포 및 State 분리를 구현했습니다.

```
infrastructure/terraform/dev/
├── erp-dev-VPC/                    # VPC, Subnet, NAT Gateway (22개 리소스)
├── erp-dev-SecurityGroups/         # Security Groups (22개 리소스)
├── erp-dev-IAM/                    # IAM Roles, Policies (18개 리소스)
├── erp-dev-Databases/              # RDS, ElastiCache (22개 리소스)
├── erp-dev-Secrets/                # Secrets Manager (4개 리소스)
├── erp-dev-EKS/                    # EKS Cluster, Node Group (11개 리소스)
├── erp-dev-LoadBalancerController/ # AWS Load Balancer Controller (10개 리소스)
├── erp-dev-APIGateway/             # API Gateway, NLB (30개 리소스)
└── erp-dev-Frontend/               # S3, CloudFront (4개 리소스)
```

**총 리소스**: 139개

## 세분화 이유

1. **독립 배포**: VPC 변경 시 EKS 재생성 불필요
2. **State 분리**: State Lock 충돌 방지, 팀 협업 용이
3. **빠른 Plan/Apply**: 15개 리소스씩 → 30초
4. **재사용성**: dev, staging, prod 환경 재사용
5. **무중단 리팩토링**: 점진적 마이그레이션

## 배포 순서

```bash
cd infrastructure/terraform/dev

# 1. VPC (2분)
cd erp-dev-VPC && terraform apply -auto-approve

# 2. Security Groups (1분)
cd ../erp-dev-SecurityGroups && terraform apply -auto-approve

# 3. IAM (1분)
cd ../erp-dev-IAM && terraform apply -auto-approve

# 4. Databases (10분)
cd ../erp-dev-Databases && terraform apply -auto-approve

# 5. Secrets (1분)
cd ../erp-dev-Secrets && terraform apply -auto-approve

# 6. EKS (15분)
cd ../erp-dev-EKS && terraform apply -auto-approve

# 7. Load Balancer Controller (3분)
cd ../erp-dev-LoadBalancerController && terraform apply -auto-approve

# 8. API Gateway + NLB (5분)
cd ../erp-dev-APIGateway && terraform apply -auto-approve

# 9. Frontend (5분)
cd ../erp-dev-Frontend && terraform apply -auto-approve
```

**총 소요 시간**: 약 40-45분

## 주요 리소스

### VPC
- CIDR: 10.0.0.0/16
- Public Subnet: 2개 (2a, 2c)
- Private Subnet: 2개 (2a, 2c)
- NAT Gateway: 2개 (고가용성)

### EKS
- Kubernetes: v1.31
- Node Group: t3.small × 2~3 (Auto Scaling)
- AZ: ap-northeast-2a, 2c

### RDS
- Engine: MySQL 8.0
- Instance: db.t3.micro
- Multi-AZ: Yes

### ElastiCache
- Engine: Redis 7.0
- Instance: cache.t3.micro

### API Gateway
- Type: HTTP API
- CORS: Enabled
- VPC Link: Private

### NLB
- Type: Network Load Balancer
- Cross-Zone Load Balancing: Enabled
- Target Groups: 4개 (각 서비스별)

## State 관리

- **Backend**: S3 (erp-terraform-state-subin-bucket)
- **Lock**: DynamoDB (erp-terraform-locks)

## 삭제 순서

역순으로 삭제:

```bash
cd erp-dev-Frontend && terraform destroy -auto-approve
cd ../erp-dev-APIGateway && terraform destroy -auto-approve
cd ../erp-dev-LoadBalancerController && terraform destroy -auto-approve
cd ../erp-dev-EKS && terraform destroy -auto-approve
cd ../erp-dev-Secrets && terraform destroy -auto-approve
cd ../erp-dev-Databases && terraform destroy -auto-approve
cd ../erp-dev-IAM && terraform destroy -auto-approve
cd ../erp-dev-SecurityGroups && terraform destroy -auto-approve
cd ../erp-dev-VPC && terraform destroy -auto-approve
```
