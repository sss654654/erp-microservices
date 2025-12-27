# 01. Secrets Manager 설정

**소요 시간**: 30분  
**목표**: AWS Secrets Manager에 Secret 생성 (Terraform보다 먼저!)

---

## 왜 Secrets를 먼저 생성하나?

**의존성**:
```
ASM Secret 생성 (수동)
    ↓
Terraform RDS 생성 (ASM에서 비밀번호 읽음)
    ↓
Helm Chart 배포 (ASM에서 비밀번호 읽음)
    ↓
Lambda 배포 (ASM에서 비밀번호 읽음)
```

**Single Source of Truth**: ASM이 유일한 비밀번호 저장소

---

## Step 1: RDS 비밀번호 파일 준비 (5분)

### 1-1. mysql-secret.json 파일 생성

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build

# 파일 생성 (실제 비밀번호 입력)
cat > mysql-secret.json << 'EOF'
{
  "username": "admin",
  "password": "YOUR_ACTUAL_PASSWORD",
  "host": "PLACEHOLDER",
  "port": "3306",
  "database": "erp"
}
EOF
```

**주의**: 
- `password`: 실제 비밀번호 입력
- `host`: PLACEHOLDER로 유지 (RDS 생성 후 업데이트)
- 이 파일은 `.gitignore`에 추가되어 Git에 올라가지 않음

---

## Step 2: AWS Secrets Manager에 Secret 생성 (5분)

```bash
aws secretsmanager create-secret \
  --name erp/dev/mysql \
  --description "ERP MySQL credentials" \
  --secret-string file://mysql-secret.json \
  --region ap-northeast-2
```

**확인:**
```bash
aws secretsmanager get-secret-value \
  --secret-id erp/dev/mysql \
  --region ap-northeast-2 \
  --query SecretString \
  --output text
```

---

## Step 3: EKS Node Role에 Secrets Manager 권한 확인 (5분)

**이미 Terraform으로 추가되어있음:**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/infrastructure/terraform/dev/erp-dev-IAM/eks-node-role

# 권한 확인
aws iam get-role-policy \
  --role-name erp-dev-eks-node-role \
  --policy-name eks-node-secrets-manager-policy \
  --region ap-northeast-2
```

**예상 출력:**
```json
{
  "Statement": [{
    "Effect": "Allow",
    "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
    "Resource": "arn:aws:secretsmanager:ap-northeast-2:806332783810:secret:erp/*"
  }]
}
```

---

## Step 4: External Secrets Operator 설치 (10분)

### 4-1. Helm으로 설치

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --wait
```

**확인:**
```bash
kubectl get pods -n external-secrets-system
```

---

## Step 5: SecretStore 생성 (5분)

```bash
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: erp-dev
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-northeast-2
      auth:
        jwt:
          serviceAccountRef:
            name: default
EOF
```

**확인:**
```bash
kubectl get secretstore -n erp-dev
# STATUS가 Valid여야 함
```

---

## 완료 체크리스트

- [x] mysql-secret.json 파일 생성 (실제 비밀번호 입력)
- [x] .gitignore에 mysql-secret.json 추가 확인
- [x] AWS Secrets Manager에 Secret 생성
- [x] Secret 값 확인 성공
- [x] EKS Node Role 권한 확인
- [ ] External Secrets Operator 설치 (02_TERRAFORM.md 이후)
- [ ] SecretStore 생성 (02_TERRAFORM.md 이후)

**중요**: External Secrets Operator는 EKS 클러스터가 생성된 후에 설치합니다.

---

## 다음 단계

**Secrets 설정 완료!**

**다음 파일을 읽으세요:**
→ **02_TERRAFORM.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 02_TERRAFORM.md
```

**중요**: 
1. 02_TERRAFORM.md에서 RDS 생성 시 ASM에서 비밀번호를 읽어옵니다.
2. RDS 생성 후 ASM Secret의 host를 업데이트해야 합니다:
   ```bash
   # RDS endpoint 확인
   cd infrastructure/terraform/dev/erp-dev-Databases/rds
   RDS_ENDPOINT=$(terraform output -raw endpoint)
   
   # ASM Secret 업데이트
   aws secretsmanager update-secret \
     --secret-id erp/dev/mysql \
     --secret-string "{\"username\":\"admin\",\"password\":\"Erp123456!\",\"host\":\"$RDS_ENDPOINT\",\"port\":\"3306\",\"database\":\"erp\"}" \
     --region ap-northeast-2
   ```

---

**"이제 비밀번호가 Git에 절대 올라가지 않습니다!"**

**소요 시간**: 30분  
**목표**: AWS Secrets Manager에 Secret 생성, External Secrets Operator 설치

---

## 현재 상황

### Terraform에서 완료된 작업

**erp-dev-IAM/eks-node-role에서 생성한 것:**
1. EKS Node Role 생성
2. EKS Node Role에 Secrets Manager 읽기 권한 추가

**확인:**
```bash
aws iam get-role-policy \
  --role-name erp-dev-eks-node-role \
  --policy-name eks-node-secrets-manager-policy \
  --region ap-northeast-2
```

### Phase 3에서 해야 할 작업

**AWS Secrets Manager에 Secret 생성:**
- Secret 이름: `erp/dev/mysql`
- Secret 내용: {username, password, host, port, database}

**External Secrets Operator 설치:**
- Kubernetes에서 Secrets Manager를 읽어 Secret 자동 생성
- Helm Chart의 ExternalSecret 리소스가 동작하도록 설정

---

## Step 1: AWS Secrets Manager에 Secret 생성 (10분)

### 1-1. RDS 정보 확인

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/infrastructure/terraform/dev/erp-dev-Databases/rds

# RDS endpoint 확인
terraform output endpoint
# 출력: erp-dev-mysql.cniqqqqiyu1n.ap-northeast-2.rds.amazonaws.com:3306
```

### 1-2. Secret 생성

```bash
aws secretsmanager create-secret \
  --name erp/dev/mysql \
  --description "ERP MySQL credentials" \
  --secret-string '{
    "username": "admin",
    "password": "123456789",
    "host": "erp-dev-mysql.cniqqqqiyu1n.ap-northeast-2.rds.amazonaws.com",
    "port": "3306",
    "database": "erp"
  }' \
  --region ap-northeast-2
```

**확인:**
```bash
aws secretsmanager get-secret-value \
  --secret-id erp/dev/mysql \
  --region ap-northeast-2 \
  --query SecretString \
  --output text

# 예상 출력:
# {"username":"admin","password":"123456789","host":"erp-dev-mysql.xxx.rds.amazonaws.com","port":"3306","database":"erp"}
```

---

## CodePipeline 강점 #1: AWS Secrets Manager 통합

**CGV와의 차별화:**
- CGV: GitLab Variables (GitLab 서버에 저장)
- ERP: AWS Secrets Manager (AWS 네이티브, 자동 로테이션, IAM 기반 접근 제어)

---

## Step 2: External Secrets Operator 설치 (10분)

### 2-1. Helm으로 설치

```bash
# Helm repo 추가
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# 설치
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --wait
```

**확인:**
```bash
kubectl get pods -n external-secrets-system

# 예상 출력:
# NAME                                                READY   STATUS    RESTARTS   AGE
# external-secrets-xxx                                1/1     Running   0          1m
# external-secrets-cert-controller-xxx                1/1     Running   0          1m
# external-secrets-webhook-xxx                        1/1     Running   0          1m
```

---

## Step 3: SecretStore 생성 (5분)

### 3-1. SecretStore 리소스 생성

```bash
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: erp-dev
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-northeast-2
      auth:
        jwt:
          serviceAccountRef:
            name: default
EOF
```

**확인:**
```bash
kubectl get secretstore -n erp-dev

# 예상 출력:
# NAME          AGE   STATUS   READY
# aws-secrets   1m    Valid    True
```

**️ STATUS가 Valid가 아니면:**
```bash
# SecretStore 상세 확인
kubectl describe secretstore aws-secrets -n erp-dev

# 일반적인 문제: EKS Node Role에 Secrets Manager 권한 없음
# → Phase 1 (Terraform)에서 이미 추가했으므로 문제 없어야 함
```

---

## Step 4: 동작 확인 (5분)

### 4-1. ExternalSecret 테스트

```bash
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-secret
  namespace: erp-dev
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: test-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: erp/dev/mysql
      property: username
  - secretKey: password
    remoteRef:
      key: erp/dev/mysql
      property: password
EOF
```

**확인:**
```bash
# ExternalSecret 상태
kubectl get externalsecret -n erp-dev

# 예상 출력:
# NAME          STORE         REFRESH INTERVAL   STATUS         READY
# test-secret   aws-secrets   1h                 SecretSynced   True

# 생성된 Secret 확인
kubectl get secret test-secret -n erp-dev -o yaml

# Secret 값 확인 (base64 디코딩)
kubectl get secret test-secret -n erp-dev -o jsonpath='{.data.username}' | base64 -d
# admin

kubectl get secret test-secret -n erp-dev -o jsonpath='{.data.password}' | base64 -d
# 123456789
```

### 4-2. 테스트 Secret 삭제

```bash
kubectl delete externalsecret test-secret -n erp-dev
kubectl delete secret test-secret -n erp-dev
```

---

##  완료 체크리스트

- [ ] External Secrets Operator 설치 완료
- [ ] Pods 모두 Running 확인
- [ ] SecretStore 생성 완료
- [ ] SecretStore STATUS가 Valid
- [ ] ExternalSecret 테스트 성공
- [ ] Secret 값 확인 성공 (admin, 123456789)
- [ ] 테스트 Secret 삭제 완료

---

##  다음 단계

**Secrets Manager 설정 완료!**

**다음 파일을 읽으세요:**
→ **03_HELM_CHART.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 03_HELM_CHART.md
```

---

##  중요 사항

### MongoDB는 어떻게 관리하나요?

**MongoDB Atlas (외부 서비스):**
- Secrets Manager에 저장 불필요
- ConfigMap에 URI 하드코딩 (개발 환경)
- values-dev.yaml에 `mongodbUri` 설정

```yaml
# helm-chart/values-dev.yaml
config:
  mongodbUri: "mongodb+srv://erp_user:***@erp-dev-cluster.4fboxqw.mongodb.net/erp"
```

**운영 환경에서는:**
- MongoDB Atlas API Key를 Secrets Manager에 저장
- 또는 MongoDB Connection String을 Secrets Manager에 저장
- ExternalSecret으로 동기화

### Terraform vs Kubernetes 역할 분담

| 작업 | 담당 | 도구 |
|------|------|------|
| Secret 생성 | Terraform | aws_secretsmanager_secret |
| IAM 권한 추가 | Terraform | aws_iam_role_policy |
| External Secrets Operator 설치 | Kubernetes | Helm |
| SecretStore 생성 | Kubernetes | kubectl apply |
| ExternalSecret 생성 | Kubernetes | Helm Chart (templates/externalsecret.yaml) |

---

**"이제 Git에 Secret이 없습니다. AWS Secrets Manager가 안전하게 관리합니다!"**
