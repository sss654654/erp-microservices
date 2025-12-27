# 07. CodePipeline 생성 (단일 파이프라인)

**소요 시간**: 1시간  
**목표**: 4개 CodePipeline → 1개 통합, GitHub 연동

---

##  현재 상황

### 기존 구조 (문제)

```
4개 CodePipeline:
├── erp-approval-request-pipeline
├── erp-approval-processing-pipeline
├── erp-employee-pipeline
└── erp-notification-pipeline

각 파이프라인:
- Source: GitHub (backend/서비스명/ 폴더만 감시)
- Build: CodeBuild (서비스별 buildspec.yml)
- Deploy: 없음 (buildspec.yml에서 kubectl set image)
```

**문제점:**
1. 서비스별 독립 배포 (의존성 무시)
2. Manifests 변경 시 배포 안 됨
3. 통합 테스트 불가능
4. 4개 파이프라인 관리 복잡

### 개선 구조 (목표)

```
1개 CodePipeline:
- Source: GitHub (전체 저장소)
- Build: CodeBuild (루트 buildspec.yml)
  - Git diff로 변경 감지
  - 변경된 서비스만 빌드
  - Helm upgrade로 배포
```

**장점:**
1. 단일 진입점
2. 서비스 간 의존성 관리
3. Manifests 변경 자동 반영
4. 통합 테스트 가능

---

##  Step 1: 기존 CodePipeline 삭제 (10분)

### 1-1. AWS Console에서 삭제

**방법 1: AWS Console**

1. AWS Console → CodePipeline
2. 4개 파이프라인 선택:
   - `erp-approval-request-pipeline`
   - `erp-approval-processing-pipeline`
   - `erp-employee-pipeline`
   - `erp-notification-pipeline`
3. Actions → Delete
4. 확인

### 1-2. AWS CLI로 삭제

```bash
# 4개 파이프라인 삭제
aws codepipeline delete-pipeline \
  --name erp-approval-request-pipeline \
  --region ap-northeast-2

aws codepipeline delete-pipeline \
  --name erp-approval-processing-pipeline \
  --region ap-northeast-2

aws codepipeline delete-pipeline \
  --name erp-employee-pipeline \
  --region ap-northeast-2

aws codepipeline delete-pipeline \
  --name erp-notification-pipeline \
  --region ap-northeast-2
```

**확인:**
```bash
aws codepipeline list-pipelines --region ap-northeast-2
# 4개 파이프라인이 사라졌는지 확인
```

---

##  Step 2: CodeBuild 프로젝트 생성 (20분)

### 2-1. AWS Console에서 생성

**CodeBuild 콘솔 → Create build project**

**프로젝트 설정:**
- Project name: `erp-unified-build`
- Description: `Unified build for all ERP microservices`

**Source:**
- Source provider: `GitHub`
- Repository: `Repository in my GitHub account`
- GitHub repository: `sss654654/erp-microservices` (본인 저장소)
- Source version: `refs/heads/main`

**Environment:**
- Environment image: `Managed image`
- Operating system: `Amazon Linux`
- Runtime(s): `Standard`
- Image: `aws/codebuild/standard:7.0`
- Image version: `Always use the latest image`
- Environment type: `Linux`
- Privileged:  **체크 필수** (Docker 빌드 필요)
- Service role: `Existing service role`
- Role ARN: `arn:aws:iam::806332783810:role/erp-dev-codebuild-role`

**Buildspec:**
- Build specifications: `Use a buildspec file`
- Buildspec name: `buildspec.yml` (루트)

**Logs:**
- CloudWatch logs:  체크
- Group name: `/aws/codebuild/erp-unified-build`
- Stream name: `build-log`

**Create build project 클릭**

### 2-2. AWS CLI로 생성

```bash
aws codebuild create-project \
  --name erp-unified-build \
  --description "Unified build for all ERP microservices" \
  --source type=GITHUB,location=https://github.com/sss654654/erp-microservices.git,buildspec=buildspec.yml \
  --artifacts type=NO_ARTIFACTS \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true \
  --service-role arn:aws:iam::806332783810:role/erp-dev-codebuild-role \
  --logs-config cloudWatchLogs={status=ENABLED,groupName=/aws/codebuild/erp-unified-build,streamName=build-log} \
  --region ap-northeast-2
```

**확인:**
```bash
aws codebuild batch-get-projects \
  --names erp-unified-build \
  --region ap-northeast-2
```

---

## 🔗 Step 3: CodePipeline 생성 (20분)

### 3-1. AWS Console에서 생성

**CodePipeline 콘솔 → Create pipeline**

#### Stage 1: Pipeline settings

- Pipeline name: `erp-unified-pipeline`
- Service role: `New service role`
- Role name: `AWSCodePipelineServiceRole-ap-northeast-2-erp-unified`
- Allow AWS CodePipeline to create a service role:  체크

**Advanced settings:**
- Artifact store: `Default location`
- Encryption key: `Default AWS Managed Key`

**Next 클릭**

#### Stage 2: Add source stage

- Source provider: `GitHub (Version 2)`
- Connection: `Create new connection` (처음이면)
  - Connection name: `github-erp-connection`
  - GitHub Apps → Install a new app
  - GitHub 로그인 → 저장소 선택 → Connect
- Repository name: `sss654654/erp-microservices`
- Branch name: `main`
- Change detection options: `Start the pipeline on source code change`  체크
- Output artifact format: `CodePipeline default`

**Next 클릭**

#### Stage 3: Add build stage

- Build provider: `AWS CodeBuild`
- Region: `Asia Pacific (Seoul)`
- Project name: `erp-unified-build` (방금 생성한 프로젝트)
- Build type: `Single build`

**Next 클릭**

#### Stage 4: Add deploy stage

- **Skip deploy stage** 클릭
  - 이유: buildspec.yml에서 helm upgrade로 배포

**Next 클릭**

#### Stage 5: Review

- 설정 확인
- **Create pipeline 클릭**

### 3-2. AWS CLI로 생성

```bash
# pipeline.json 파일 생성
cat > pipeline.json << 'EOF'
{
  "pipeline": {
    "name": "erp-unified-pipeline",
    "roleArn": "arn:aws:iam::806332783810:role/service-role/AWSCodePipelineServiceRole-ap-northeast-2-erp-unified",
    "artifactStore": {
      "type": "S3",
      "location": "codepipeline-ap-northeast-2-123456789"
    },
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "Source",
            "actionTypeId": {
              "category": "Source",
              "owner": "AWS",
              "provider": "CodeStarSourceConnection",
              "version": "1"
            },
            "configuration": {
              "ConnectionArn": "arn:aws:codeconnections:ap-northeast-2:806332783810:connection/xxxxx",
              "FullRepositoryId": "sss654654/erp-microservices",
              "BranchName": "main",
              "OutputArtifactFormat": "CODE_ZIP"
            },
            "outputArtifacts": [
              {
                "name": "SourceArtifact"
              }
            ]
          }
        ]
      },
      {
        "name": "Build",
        "actions": [
          {
            "name": "Build",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "configuration": {
              "ProjectName": "erp-unified-build"
            },
            "inputArtifacts": [
              {
                "name": "SourceArtifact"
              }
            ],
            "outputArtifacts": [
              {
                "name": "BuildArtifact"
              }
            ]
          }
        ]
      }
    ]
  }
}
EOF

# 파이프라인 생성
aws codepipeline create-pipeline \
  --cli-input-json file://pipeline.json \
  --region ap-northeast-2
```

---

##  Step 4: 검증 (10분)

### 4-1. 파이프라인 확인

**AWS Console:**
1. CodePipeline → `erp-unified-pipeline`
2. 상태 확인:
   - Source: Succeeded
   - Build: In Progress / Succeeded

**AWS CLI:**
```bash
aws codepipeline get-pipeline-state \
  --name erp-unified-pipeline \
  --region ap-northeast-2
```

### 4-2. CodeBuild 로그 확인

**AWS Console:**
1. CodeBuild → Build history
2. `erp-unified-build` 클릭
3. Build logs 확인:
   - ECR 로그인 성공
   - Maven 빌드 성공
   - Docker 빌드/푸시 성공
   - ECR 스캔 성공
   - Helm 배포 성공

**AWS CLI:**
```bash
# 최근 빌드 ID 확인
BUILD_ID=$(aws codebuild list-builds-for-project \
  --project-name erp-unified-build \
  --region ap-northeast-2 \
  --query 'ids[0]' \
  --output text)

# 빌드 로그 확인
aws codebuild batch-get-builds \
  --ids $BUILD_ID \
  --region ap-northeast-2 \
  --query 'builds[0].logs.deepLink' \
  --output text
```

### 4-3. EKS 배포 확인

```bash
# Pod 상태 확인
kubectl get pods -n erp-dev

# Service 확인
kubectl get svc -n erp-dev

# Helm 히스토리 확인
helm history erp-microservices -n erp-dev

# 이미지 태그 확인
kubectl get deployment -n erp-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
```

---

##  Step 5: Git Push 테스트 (10분)

### 5-1. 코드 변경

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project

# Employee Service 코드 변경 (간단한 주석 추가)
echo "// Test change" >> backend/employee-service/src/main/java/com/erp/employee/EmployeeController.java

# Git 커밋
git add .
git commit -m "Test: Trigger unified pipeline"
git push origin main
```

### 5-2. 파이프라인 자동 트리거 확인

**AWS Console:**
1. CodePipeline → `erp-unified-pipeline`
2. 자동으로 실행되는지 확인
3. Source Stage → Build Stage 진행 확인

**예상 동작:**
1. GitHub Webhook → CodePipeline 트리거
2. Source Stage: GitHub에서 코드 가져오기
3. Build Stage: CodeBuild 실행
   - Git diff로 employee-service 변경 감지
   - employee-service만 빌드
   - ECR 푸시 + 스캔
   - Helm values 업데이트
   - helm upgrade 실행
4. EKS에 employee-service만 재배포

### 5-3. 변경 감지 로그 확인

**CodeBuild 로그에서 확인:**
```
Detecting changed services...
Changed files: backend/employee-service/src/main/java/com/erp/employee/EmployeeController.java
Services to build: employee-service
Building employee-service...
```

---

##  트러블슈팅

### 문제 1: GitHub 연결 실패

**증상:**
```
Could not connect to GitHub repository
```

**해결:**
1. CodePipeline → Settings → Connections
2. `github-erp-connection` 상태 확인
3. Status가 `Pending`이면:
   - Update pending connection 클릭
   - GitHub 로그인 → 권한 승인

### 문제 2: CodeBuild 권한 오류

**증상:**
```
AccessDeniedException: User is not authorized to perform: eks:DescribeCluster
```

**해결:**
```bash
# CodeBuild Role에 EKS 권한 추가 (04_BUILDSPEC.md Step 3 참고)
aws iam put-role-policy \
  --role-name erp-dev-codebuild-role \
  --policy-name EKSDescribePolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster", "eks:ListClusters"],
      "Resource": "*"
    }]
  }'
```

### 문제 3: Helm 배포 실패

**증상:**
```
Error: UPGRADE FAILED: unable to build kubernetes objects
```

**해결:**
```bash
# Helm Chart 문법 확인
cd helm-chart
helm lint . -f values-dev.yaml

# Dry-run 테스트
helm template . -f values-dev.yaml > test-output.yaml
kubectl apply -f test-output.yaml --dry-run=client
```

### 문제 4: ECR 스캔 타임아웃

**증상:**
```
WARNING: Scan timeout for employee-service, proceeding with deployment
```

**원인:**
- ECR 스캔이 10분 이상 소요
- buildspec.yml의 MAX_RETRIES=30 (5분) 초과

**해결:**
```yaml
# buildspec.yml 수정
MAX_RETRIES=60  # 10분으로 증가
```

---

##  완료 체크리스트

- [ ] 기존 4개 CodePipeline 삭제
- [ ] CodeBuild 프로젝트 생성 (`erp-unified-build`)
- [ ] CodePipeline 생성 (`erp-unified-pipeline`)
- [ ] GitHub 연결 설정 완료
- [ ] 파이프라인 첫 실행 성공
- [ ] CodeBuild 로그 확인 (ECR 스캔, Helm 배포)
- [ ] EKS 배포 확인 (Pod, Service, Helm)
- [ ] Git Push 테스트 성공
- [ ] 변경 감지 로직 동작 확인

---

##  다음 단계

**CodePipeline 생성 완료!**

**다음 파일을 읽으세요:**
→ **06_VERIFICATION.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 06_VERIFICATION.md
```

---

##  개선 효과

### Before (4개 파이프라인)

```
파이프라인 관리: 4개
배포 시간: 각 5분 × 4 = 20분
변경 감지: 폴더별 감시 (부정확)
Manifests 반영: 안 됨
롤백: 불가능
```

### After (1개 파이프라인)

```
파이프라인 관리: 1개
배포 시간: 변경된 서비스만 (평균 5분)
변경 감지: Git diff (정확)
Manifests 반영: 자동
롤백: helm rollback (즉시)
```

---

**"단일 파이프라인으로 모든 서비스를 관리합니다. 이제 Git이 진실입니다!"**
