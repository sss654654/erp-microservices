# 03. 이미지 빌드 & ECR 푸시

**소요 시간**: 30분  
**목표**: 모든 서비스 이미지를 빌드하고 ECR에 푸시

---

## 왜 이미지를 먼저 빌드하나?

**의존성**:
```
ECR Repository 생성 (Terraform)
    ↓
이미지 빌드 & ECR 푸시 (수동)
    ↓
Helm Chart 배포 (이미지 사용)
    ↓
Lambda 배포 (이미지 사용)
```

**이미지가 없으면 Pod가 ImagePullBackOff 에러 발생**

---

## 준비 사항

### 1. ECR Repository 확인

```bash
aws ecr describe-repositories --region ap-northeast-2 --query 'repositories[?contains(repositoryName, `erp`)].repositoryName' --output table
```

**예상 출력:**
```
---------------------------------
|   DescribeRepositories        |
+-------------------------------+
|  erp/employee-service-lambda  |
|  erp/approval-request-service |
|  erp/approval-processing-service |
|  erp/notification-service     |
+-------------------------------+
```

### 2. ECR 로그인

```bash
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com
```

---

## Step 1: Employee Service (Lambda) 이미지 빌드 (10분)

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/backend/employee-service

# Maven 빌드
mvn clean package -DskipTests

# Lambda용 Docker 이미지 빌드
docker build -f Dockerfile.lambda -t employee-service-lambda:latest .

# ECR 태그
docker tag employee-service-lambda:latest 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service-lambda:latest

# ECR 푸시
docker push 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service-lambda:latest
```

**확인:**
```bash
aws ecr describe-images --repository-name erp/employee-service-lambda --region ap-northeast-2 --query 'imageDetails[0].imageTags' --output text
```

---

## Step 2: Approval Request Service 이미지 빌드 (5분)

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/backend/approval-request-service

# Maven 빌드
mvn clean package -DskipTests

# Docker 이미지 빌드
docker build -t approval-request-service:latest .

# ECR 태그
docker tag approval-request-service:latest 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-request-service:latest

# ECR 푸시
docker push 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-request-service:latest
```

**확인:**
```bash
aws ecr describe-images --repository-name erp/approval-request-service --region ap-northeast-2 --query 'imageDetails[0].imageTags' --output text
```

---

## Step 3: Approval Processing Service 이미지 빌드 (5분)

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/backend/approval-processing-service

# Maven 빌드
mvn clean package -DskipTests

# Docker 이미지 빌드
docker build -t approval-processing-service:latest .

# ECR 태그
docker tag approval-processing-service:latest 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-processing-service:latest

# ECR 푸시
docker push 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-processing-service:latest
```

**확인:**
```bash
aws ecr describe-images --repository-name erp/approval-processing-service --region ap-northeast-2 --query 'imageDetails[0].imageTags' --output text
```

---

## Step 4: Notification Service 이미지 빌드 (5분)

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/backend/notification-service

# Maven 빌드
mvn clean package -DskipTests

# Docker 이미지 빌드
docker build -t notification-service:latest .

# ECR 태그
docker tag notification-service:latest 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/notification-service:latest

# ECR 푸시
docker push 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/notification-service:latest
```

**확인:**
```bash
aws ecr describe-images --repository-name erp/notification-service --region ap-northeast-2 --query 'imageDetails[0].imageTags' --output text
```

---

## Step 5: 전체 확인 (5분)

```bash
# 모든 ECR Repository 이미지 확인
for repo in employee-service-lambda approval-request-service approval-processing-service notification-service; do
  echo "=== $repo ==="
  aws ecr describe-images --repository-name erp/$repo --region ap-northeast-2 --query 'imageDetails[0].[imagePushedAt,imageTags]' --output text
done
```

**예상 출력:**
```
=== employee-service-lambda ===
2025-12-28T01:15:00+09:00    latest

=== approval-request-service ===
2025-12-28T01:16:00+09:00    latest

=== approval-processing-service ===
2025-12-28T01:17:00+09:00    latest

=== notification-service ===
2025-12-28T01:18:00+09:00    latest
```

---

## 완료 체크리스트

- [ ] ECR 로그인 성공
- [ ] Employee Service (Lambda) 이미지 빌드 & 푸시
- [ ] Approval Request Service 이미지 빌드 & 푸시
- [ ] Approval Processing Service 이미지 빌드 & 푸시
- [ ] Notification Service 이미지 빌드 & 푸시
- [ ] 모든 ECR Repository에 이미지 확인

---

## 다음 단계

**이미지 빌드 완료!**

**다음 파일을 읽으세요:**
→ **04_LAMBDA_DEPLOY.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 04_LAMBDA_DEPLOY.md
```

**중요**: 
- Lambda는 이미 Terraform으로 생성되어 있습니다.
- 이미지가 업데이트되었으므로 Lambda 함수를 업데이트합니다.

---

## 트러블슈팅

### Maven 빌드 실패

```bash
# Java 버전 확인
java -version  # 17이어야 함

# Maven 버전 확인
mvn -version
```

### Docker 빌드 실패

```bash
# Docker 실행 확인
docker ps

# 이전 이미지 삭제
docker rmi $(docker images -q)
```

### ECR 푸시 실패

```bash
# ECR 로그인 재시도
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com

# Repository 존재 확인
aws ecr describe-repositories --repository-names erp/approval-request-service --region ap-northeast-2
```

---

**"이제 모든 이미지가 ECR에 준비되었습니다!"**
