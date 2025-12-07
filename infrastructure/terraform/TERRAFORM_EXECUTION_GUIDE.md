# Terraform 실행 가이드

## 실행 순서

### 1. Backend 설정 (S3 + DynamoDB)
```bash
cd backend-setup
terraform init
terraform apply
```

### 2. VPC (네트워크 기반)
```bash
cd ../dev/vpc
terraform init
terraform apply
```

### 3. Security - 1차 실행 (기본 리소스만)
```bash
cd ../security
terraform init
terraform apply \
  -target=aws_security_group.alb \
  -target=aws_security_group.eks \
  -target=aws_security_group.rds \
  -target=aws_security_group.elasticache \
  -target=aws_iam_role.eks_cluster \
  -target=aws_iam_role.eks_node \
  -target=aws_iam_role_policy_attachment.eks_cluster_policy \
  -target=aws_iam_role_policy_attachment.eks_worker_node_policy \
  -target=aws_iam_role_policy_attachment.eks_cni_policy \
  -target=aws_iam_role_policy_attachment.eks_container_registry_policy
```

**주의:** EKS Cluster SG 규칙은 아직 주석 처리 상태 유지

### 4. Databases (데이터 저장소)
```bash
cd ../databases
terraform init
terraform apply -var="mysql_password=YourSecurePassword123!"
```

### 5. EKS (컨테이너 오케스트레이션)
```bash
cd ../eks
terraform init
terraform apply
```

**소요 시간:** 약 15-20분

### 6. Security - 2차 실행 (EKS Cluster SG 규칙 추가)

**실행:**
```bash
cd ../security
terraform apply
```

**설명:**
- `-target` 옵션 없이 전체 실행
- 1차 실행에서 제외되었던 3개 규칙이 추가됨:
  - `aws_security_group_rule.rds_from_eks_cluster`
  - `aws_security_group_rule.eks_cluster_from_alb`
  - `aws_security_group_rule.elasticache_from_eks_cluster`
- EKS가 생성한 `cluster_security_group_id`를 참조하여 규칙 생성

### 7. ALB (로드 밸런서)
```bash
cd ../alb
terraform init
terraform apply
```

### 8. API Gateway (API 관리)
```bash
cd ../api-gateway
terraform init
terraform apply
```

---

## 왜 Security 모듈을 2단계로 실행하는가?

### 핵심 문제: EKS Cluster Security Group 자동 생성

EKS는 클러스터 생성 시 **자동으로** Cluster Security Group을 생성하며, 이것이 실제 Worker Node에 적용됩니다.

| SG 종류 | 생성 방법 | 적용 대상 | 사용 여부 |
|---------|----------|----------|----------|
| Terraform EKS SG | 수동 생성 (`dev/security/main.tf`) | Control Plane ENI | 사용 안 됨 |
| **EKS Cluster SG** | **EKS 자동 생성** | **Worker Node (Pod)** | **실제 사용** |

**문제 발생 과정:**
1. Terraform으로 EKS SG 생성 (`aws_security_group.eks`)
2. RDS SG가 이 Terraform EKS SG만 허용하도록 설정
3. 하지만 실제 Worker Node는 EKS가 자동 생성한 Cluster SG 사용
4. RDS는 Terraform EKS SG만 허용 → Worker Node(실제 Cluster SG)는 차단
5. **결과: Pod → RDS 연결 실패**

### 해결 방법: 2단계 실행

**1차 실행 (EKS 생성 전):**
- IAM Roles, Security Groups 생성
- `-target` 옵션으로 필요한 리소스만 생성
- EKS Cluster SG 규칙은 **자동으로 제외됨** (EKS outputs 없어서 오류 발생)

**EKS 생성:**
- EKS가 Cluster Security Group 자동 생성
- `cluster_security_group_id` output 생성됨

**2차 실행 (EKS 생성 후):**
- `-target` 옵션 없이 `terraform apply` 전체 실행
- 1차에서 제외되었던 3개 규칙이 추가됨:
  - `rds_from_eks_cluster`: Pod → RDS 연결 허용
  - `eks_cluster_from_alb`: ALB → Pod Health Check 허용
  - `elasticache_from_eks_cluster`: Pod → ElastiCache 연결 허용

### 주석 처리 불필요

`-target` 옵션이 지정한 리소스만 생성하므로, 코드에서 주석 처리할 필요가 없습니다.
- 1차 실행: `-target`으로 10개 리소스만 생성 → 3개 규칙 자동 제외
- 2차 실행: 전체 실행 → 3개 규칙 추가

### 순환 의존성 문제

- Security 모듈이 EKS outputs 참조 (`cluster_security_group_id`)
- EKS 모듈이 Security outputs 참조 (`eks_cluster_role_arn`, `eks_sg_id`)
- 동시 생성 불가 → 2단계 분리 실행 필요

---

## 전체 소요 시간
약 50-60분

---

## 리소스 확인

### VPC
```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=erp-dev-vpc" --region ap-northeast-2
```

### EKS
```bash
aws eks describe-cluster --name erp-dev --region ap-northeast-2
kubectl get nodes
```

### RDS
```bash
aws rds describe-db-instances --db-instance-identifier erp-dev-mysql --region ap-northeast-2
```

### ElastiCache
```bash
aws elasticache describe-cache-clusters --cache-cluster-id erp-dev-redis --region ap-northeast-2
```

### ALB
```bash
aws elbv2 describe-load-balancers --region ap-northeast-2 --query 'LoadBalancers[?contains(LoadBalancerName, `erp-dev`)]'
```

### API Gateway
```bash
aws apigatewayv2 get-apis --region ap-northeast-2 --query 'Items[?Name==`erp-dev-api`]'
```

---

## Outputs 확인

각 모듈 디렉토리에서:
```bash
terraform output
```

중요 Outputs:
- VPC: `vpc_id`, `private_subnet_ids`, `data_subnet_ids`
- Security: `eks_cluster_role_arn`, `eks_node_role_arn`
- Databases: `rds_endpoint`, `elasticache_endpoint`
- EKS: `cluster_endpoint`, `cluster_security_group_id`
- ALB: `alb_dns_name`, `target_group_arns`
- API Gateway: `api_gateway_invoke_url`
