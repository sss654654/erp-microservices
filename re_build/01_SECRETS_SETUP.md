# 01. Secrets Manager 설정

**소요 시간**: 10분  
**목표**: AWS Secrets Manager에 RDS 자격 증명 생성 (Terraform보다 먼저!)

---

## 왜 Secrets를 먼저 생성하나?

**의존성**:
```
ASM Secret 생성 (수동)
    ↓
Terraform RDS 생성 (ASM에서 비밀번호 읽음)
```

**Single Source of Truth**: ASM이 유일한 비밀번호 저장소

---

## Step 1: RDS 비밀번호 파일 준비 (5분)

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
- `host`: PLACEHOLDER로 유지 (RDS 생성 후 자동 업데이트)
- 이 파일은 `.gitignore`에 추가되어 Git에 올라가지 않음
- **비밀번호는 이 파일에만 존재해야 함**

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

## 완료 체크리스트

- [x] mysql-secret.json 파일 생성 (실제 비밀번호 입력)
- [x] .gitignore에 mysql-secret.json 추가 확인
- [x] AWS Secrets Manager에 Secret 생성
- [x] Secret 값 확인 성공

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
- 02_TERRAFORM.md에서 RDS 생성 시 ASM에서 비밀번호를 읽어옵니다.
- RDS 생성 후 ASM Secret의 host가 자동으로 업데이트됩니다.
- EKS Node Role의 Secrets Manager 권한은 Terraform으로 자동 설정됩니다.

---

**"이제 비밀번호가 Git에 절대 올라가지 않습니다!"**
