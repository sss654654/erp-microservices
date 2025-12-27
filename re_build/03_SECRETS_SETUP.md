# 03. Secrets Manager 설정

**소요 시간**: 20분  
**목표**: External Secrets Operator 설치, Kubernetes Secret 자동 동기화

---

## 📊 현재 상황

### Phase 1 (Terraform)에서 이미 완료된 작업

**erp-dev-Secrets 모듈이 생성한 것:**
1. ✅ AWS Secrets Manager Secret: `erp/dev/mysql`
2. ✅ Secret 내용: {username, password, host, port, database}
3. ✅ EKS Node Role에 Secrets Manager 읽기 권한 추가

**확인:**
```bash
aws secretsmanager get-secret-value \
  --secret-id erp/dev/mysql \
  --region ap-northeast-2 \
  --query SecretString \
  --output text

# 출력:
# {"username":"admin","password":"123456789","host":"erp-dev-mysql.xxx.rds.amazonaws.com","port":"3306","database":"erp"}
```

### Phase 3에서 해야 할 작업

**External Secrets Operator 설치:**
- Kubernetes에서 Secrets Manager를 읽어 Secret 자동 생성
- Helm Chart의 ExternalSecret 리소스가 동작하도록 설정

---

## 🎯 CodePipeline 강점 #1: AWS Secrets Manager 통합

**CGV와의 차별화:**
- CGV: GitLab Variables (GitLab 서버에 저장)
- ERP: AWS Secrets Manager (AWS 네이티브, 자동 로테이션, IAM 기반 접근 제어)

---

## 🚀 Step 1: External Secrets Operator 설치 (10분)

### 1-1. Helm으로 설치

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

## 🔧 Step 2: SecretStore 생성 (5분)

### 2-1. SecretStore 리소스 생성

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

**⚠️ STATUS가 Valid가 아니면:**
```bash
# SecretStore 상세 확인
kubectl describe secretstore aws-secrets -n erp-dev

# 일반적인 문제: EKS Node Role에 Secrets Manager 권한 없음
# → Phase 1 (Terraform)에서 이미 추가했으므로 문제 없어야 함
```

---

## ✅ Step 3: 동작 확인 (5분)

### 3-1. ExternalSecret 테스트

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

### 3-2. 테스트 Secret 삭제

```bash
kubectl delete externalsecret test-secret -n erp-dev
kubectl delete secret test-secret -n erp-dev
```

---

## 📊 완료 체크리스트

- [ ] External Secrets Operator 설치 완료
- [ ] Pods 모두 Running 확인
- [ ] SecretStore 생성 완료
- [ ] SecretStore STATUS가 Valid
- [ ] ExternalSecret 테스트 성공
- [ ] Secret 값 확인 성공 (admin, 123456789)
- [ ] 테스트 Secret 삭제 완료

---

## 🎯 다음 단계

**Secrets Manager 설정 완료!**

**다음 파일을 읽으세요:**
→ **04_BUILDSPEC.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 04_BUILDSPEC.md
```

---

## 📝 중요 사항

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
