# 06. buildspec.yml 작성 (CodePipeline 강점 극대화)

**소요 시간**: 3시간  
**목표**: 7가지 CodePipeline 강점을 모두 구현

---

##  06단계에서 구현할 기능

### CGV와 차별화 (4가지)

| 기능 | CGV (GitLab CI) | ERP (CodePipeline) | 구현 위치 |
|------|----------------|-------------------|----------|
| Secret 관리 | GitLab Variables |  AWS Secrets Manager | 01단계 완료 |
| 단일 파이프라인 | 서비스별 독립 |  Helm Chart 통합 | 05단계 완료 |
| **설정 관리** | **하드코딩** | ** Parameter Store** | **Step 1** |
| **로그 관리** | **GitLab Logs** | ** CloudWatch Logs** | **Step 2** |
| **트레이싱** | **없음** | ** X-Ray 통합** | **Step 3** |
| **이미지 스캔 + 변경 감지** | **수동 + 전체 빌드** | ** ECR 스캔 + Git diff** | **Step 4** |

---

## Step 1: Parameter Store 활용 (20분)

### 1-1. 왜 필요한가?

**현재 문제:**
```yaml
# buildspec.yml 하드코딩
env:
  variables:
    AWS_ACCOUNT_ID: "806332783810"      #  계정 변경 시 수정 필요
    AWS_REGION: "ap-northeast-2"        #  환경별 분리 불가
    EKS_CLUSTER_NAME: "erp-dev"         #  Git에 노출
```

**Parameter Store 사용 시:**
```yaml
env:
  parameter-store:
    AWS_ACCOUNT_ID: /erp/dev/account-id              #  중앙 관리
    AWS_REGION: /erp/dev/region                      #  환경별 분리
    EKS_CLUSTER_NAME: /erp/dev/eks/cluster-name      #  Git에 안전
```

### 1-2. Terraform으로 Parameter 생성

```bash
cd infrastructure/terraform/dev/erp-dev-ParameterStore

terraform init
terraform apply -auto-approve
```

**생성되는 6개 Parameter:**
```
/erp/dev/account-id              # data.aws_caller_identity로 자동
/erp/dev/region                  # ap-northeast-2
/erp/dev/eks/cluster-name        # remote_state.eks로 자동
/erp/dev/ecr/repository-prefix   # erp
/erp/dev/project-name            # erp
/erp/dev/environment             # dev
```

**확인:**
```bash
terraform output
```

### 1-3. CodeBuild Role 권한 확인

**이미 02_TERRAFORM.md에서 완료:**
```bash
aws iam list-role-policies --role-name erp-dev-codebuild-role --region ap-northeast-2
# codebuild-ssm-policy 
```

---

## Step 2: CloudWatch Logs 중앙 집중 (30분)

### 2-1. 개념 이해: CloudWatch Logs가 뭔가요?

**쉽게 설명하면:**
- Pod는 컨테이너 안에서 실행되는 프로그램입니다
- 프로그램이 실행되면 로그(기록)가 생성됩니다
- 이 로그를 어디에 저장할까요?

**현재 상황 (문제):**
```
Pod 안에만 로그 저장
    ↓
Pod 재시작 → 로그 사라짐 
Pod 여러 개 → 각각 확인해야 함 
```

**CloudWatch Logs 사용 (해결):**
```
Pod 로그 → Fluent Bit → CloudWatch Logs (AWS 저장소)
    ↓
Pod 재시작해도 로그 유지 
모든 Pod 로그 한 곳에서 검색 
```

### 2-2. 실제 예시로 이해하기

**시나리오: 에러 발생 시**

**Before (CloudWatch 없음):**
```bash
# 1. 어느 Pod에서 에러 났는지 모름
kubectl get pods -n erp-dev
# approval-request-service-abc123
# approval-request-service-def456

# 2. 각 Pod 로그 일일이 확인
kubectl logs approval-request-service-abc123 -n erp-dev
kubectl logs approval-request-service-def456 -n erp-dev

# 3. Pod 재시작되면 로그 사라짐
kubectl delete pod approval-request-service-abc123 -n erp-dev
# 로그 영구 소실 
```

**After (CloudWatch 사용):**
```bash
# 1. AWS Console → CloudWatch Logs
# 2. /aws/eks/erp-dev/application 클릭
# 3. 검색창에 "ERROR" 입력
# 4. 모든 Pod의 에러 로그가 한 번에 검색됨 
# 5. Pod 재시작해도 로그 유지 
```

### 2-3. 구성 요소 3가지

#### ① IAM 권한 (EKS Node가 CloudWatch에 쓸 수 있게)

**왜 필요한가?**
- EKS Node(서버)가 CloudWatch에 로그를 보내려면 권한 필요
- 집에 택배 보내려면 주소 알아야 하는 것과 같음

**설정 내용:**
```hcl
# infrastructure/terraform/dev/erp-dev-IAM/eks-node-role/eks-node-role.tf
resource "aws_iam_role_policy" "eks_node_cloudwatch_logs" {
  role = aws_iam_role.eks_node.name
  name = "eks-node-cloudwatch-logs-policy"

  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",      # 로그 그룹 만들기
        "logs:CreateLogStream",     # 로그 스트림 만들기
        "logs:PutLogEvents",        # 로그 쓰기
        "logs:DescribeLogStreams"   # 로그 스트림 확인
      ]
      Resource = "arn:aws:logs:ap-northeast-2:806332783810:log-group:/aws/eks/erp-dev/*"
    }]
  })
}
```

**확인 방법:**
```bash
# IAM 권한 확인
aws iam list-role-policies --role-name erp-dev-eks-node-role --region ap-northeast-2

# 출력에 "eks-node-cloudwatch-logs-policy" 있으면 성공 
```

#### ② Fluent Bit (로그 수집기)

**왜 필요한가?**
- Pod 로그를 자동으로 CloudWatch로 보내주는 프로그램
- 우체부가 편지를 수거해서 우체국으로 보내는 것과 같음

**동작 방식:**
```
1. Fluent Bit이 각 Node에 1개씩 실행됨 (DaemonSet)
2. 해당 Node의 모든 Pod 로그를 읽음
3. CloudWatch Logs로 전송
```

**설정 내용:**
```yaml
# helm-chart/templates/fluent-bit.yaml
apiVersion: apps/v1
kind: DaemonSet  # 각 Node에 1개씩 실행
metadata:
  name: fluent-bit
  namespace: amazon-cloudwatch
spec:
  template:
    spec:
      containers:
      - name: fluent-bit
        image: public.ecr.aws/aws-observability/aws-for-fluent-bit:latest
        env:
        - name: AWS_REGION
          value: ap-northeast-2
        - name: CLUSTER_NAME
          value: erp-dev
        - name: LOG_GROUP_NAME
          value: /aws/eks/erp-dev/application
```

**확인 방법:**
```bash
# Fluent Bit Pod 확인
kubectl get pods -n amazon-cloudwatch

# 출력 예시:
# NAME               READY   STATUS    RESTARTS   AGE
# fluent-bit-xxxxx   1/1     Running   0          10m
# fluent-bit-yyyyy   1/1     Running   0          10m
# → Node 2개이므로 Pod 2개 

# Fluent Bit 로그 확인 (정상 동작 여부)
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=fluent-bit --tail=20

# 출력에 "Fluent Bit v2.x started" 있으면 성공 
```

#### ③ CloudWatch Log Group (로그 저장소)

**왜 필요한가?**
- 로그를 저장할 폴더 같은 것
- 서비스별로 폴더를 나눠서 관리

**구조:**
```
/aws/eks/erp-dev/application (Log Group)
├── approval-request-service-abc123 (Log Stream)
│   └── 2025-12-28 16:00:00 [INFO] Started application
│   └── 2025-12-28 16:00:01 [ERROR] Connection failed
├── approval-request-service-def456 (Log Stream)
│   └── 2025-12-28 16:00:00 [INFO] Started application
└── notification-service-xyz789 (Log Stream)
    └── 2025-12-28 16:00:00 [INFO] WebSocket connected
```

**확인 방법:**
```bash
# CloudWatch Log Group 확인
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/erp-dev \
  --region ap-northeast-2 \
  --query 'logGroups[*].logGroupName' \
  --output table

# 출력 예시:
# --------------------------------
# |   DescribeLogGroups          |
# +------------------------------+
# |  /aws/eks/erp-dev/application|
# +------------------------------+
#  Log Group 생성됨

# Log Stream 확인 (Pod별 로그)
aws logs describe-log-streams \
  --log-group-name /aws/eks/erp-dev/application \
  --region ap-northeast-2 \
  --max-items 5 \
  --query 'logStreams[*].logStreamName' \
  --output table

# 출력 예시:
# ------------------------------------------------
# |   DescribeLogStreams                         |
# +----------------------------------------------+
# |  approval-request-service-abc123             |
# |  approval-request-service-def456             |
# |  notification-service-xyz789                 |
# +----------------------------------------------+
#  Pod별 Log Stream 생성됨
```

### 2-4. 실제 로그 확인하기

#### 방법 1: AWS CLI (터미널)

```bash
# 최근 5분 로그 확인
aws logs tail /aws/eks/erp-dev/application --since 5m --region ap-northeast-2

# 실시간 로그 스트리밍 (계속 보기)
aws logs tail /aws/eks/erp-dev/application --follow --region ap-northeast-2

# 특정 키워드 검색 (ERROR만)
aws logs tail /aws/eks/erp-dev/application --since 1h --region ap-northeast-2 | grep ERROR
```

#### 방법 2: AWS Console (웹)

```
1. AWS Console 로그인
2. CloudWatch 서비스 클릭
3. 왼쪽 메뉴 → Logs → Log groups
4. /aws/eks/erp-dev/application 클릭
5. Log streams에서 Pod 선택
6. 로그 확인

검색 기능:
- Filter events 입력창에 "ERROR" 입력
- 모든 Pod의 에러 로그가 한 번에 검색됨 
```

#### 방법 3: CloudWatch Insights (고급 검색)

```
1. CloudWatch → Logs → Insights
2. Log group 선택: /aws/eks/erp-dev/application
3. 쿼리 입력:

# 최근 1시간 에러 로그 개수
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)

# 서비스별 에러 개수
fields @timestamp, @message
| filter @message like /ERROR/
| parse @logStream /(?<service>[^-]+)-service/
| stats count() by service
```

### 2-5. 완료 확인 체크리스트

```bash
#  1. IAM 권한 확인
aws iam list-role-policies --role-name erp-dev-eks-node-role --region ap-northeast-2 | grep cloudwatch

#  2. Fluent Bit Pod 확인
kubectl get pods -n amazon-cloudwatch
# 2개 Pod Running 확인

#  3. CloudWatch Log Group 확인
aws logs describe-log-groups --log-group-name-prefix /aws/eks/erp-dev --region ap-northeast-2

#  4. Log Stream 확인 (Pod별 로그)
aws logs describe-log-streams --log-group-name /aws/eks/erp-dev/application --region ap-northeast-2 --max-items 5

#  5. 실제 로그 확인
aws logs tail /aws/eks/erp-dev/application --since 5m --region ap-northeast-2
```

### 2-6. 왜 이게 중요한가? (실무 관점)

**시나리오 1: 새벽 3시 장애 발생**
```
Before:
- 새벽에 Pod 재시작됨
- 아침에 출근해서 확인하려니 로그 사라짐 
- 원인 파악 불가

After:
- CloudWatch에 모든 로그 저장됨
- 아침에 출근해서 CloudWatch 확인
- 새벽 3시 로그 그대로 남아있음 
- 원인 파악 가능
```

**시나리오 2: 특정 에러 패턴 찾기**
```
Before:
- 10개 Pod 로그를 일일이 확인
- kubectl logs 10번 실행
- 시간 낭비

After:
- CloudWatch Insights 쿼리 1번
- 모든 Pod에서 에러 패턴 검색
- 1분 안에 완료 
```

**시나리오 3: 알람 설정 (선택 사항)**
```
CloudWatch Logs → CloudWatch Alarm
- "ERROR" 키워드가 10번 이상 나오면
- Slack/Email 알람 발송
- 자동 모니터링 

참고: 알람 설정은 현재 프로젝트 범위에 포함되지 않음
```

---

### 2-7. Step 2 완료 확인 및 정리

#### 완료된 작업 체크리스트

```bash
# 1. IAM 권한 확인
aws iam list-role-policies --role-name erp-dev-eks-node-role --region ap-northeast-2 | grep cloudwatch
# 출력: eks-node-cloudwatch-logs-policy

# 2. Fluent Bit Pod 확인
kubectl get pods -n amazon-cloudwatch
# 출력: fluent-bit-xxxxx 2개 Running

# 3. CloudWatch Log Group 확인
aws logs describe-log-groups --log-group-name /aws/eks/erp-dev/application --region ap-northeast-2
# 출력: logGroupName: /aws/eks/erp-dev/application

# 4. Log Stream 확인 (Pod별 로그)
aws logs describe-log-streams --log-group-name /aws/eks/erp-dev/application --region ap-northeast-2 --max-items 5
# 출력: Pod별 Log Stream 목록

# 5. 실제 로그 확인
aws logs tail /aws/eks/erp-dev/application --since 5m --region ap-northeast-2
# 출력: 최근 5분간의 로그
```

#### 현재 Log Group 구조

```
AWS CloudWatch Logs
├── /aws/eks/erp-dev/application (EKS Pod 로그)
│   ├── fluentbit-kube...approval-request-service-xxx (Pod 1)
│   ├── fluentbit-kube...approval-request-service-yyy (Pod 2)
│   ├── fluentbit-kube...approval-processing-service-xxx (Pod 1)
│   ├── fluentbit-kube...approval-processing-service-yyy (Pod 2)
│   ├── fluentbit-kube...notification-service-xxx (Pod 1)
│   └── fluentbit-kube...notification-service-yyy (Pod 2)
│
├── /aws/lambda/erp-dev-employee-service (Lambda 로그)
│   └── Lambda 실행마다 자동 생성
│
└── /aws/apigateway/erp-dev-api (API Gateway 로그, 선택)
    └── API 요청 로그
```

#### 로그 흐름 정리

**EKS Pod 로그:**
```
1. Pod가 stdout/stderr로 로그 출력
   예: System.out.println("Hello")

2. Kubernetes가 /var/log/containers/*.log에 저장

3. Fluent Bit (DaemonSet)이 해당 파일 읽음
   - 각 Node에 1개씩 실행
   - 해당 Node의 모든 Pod 로그 수집

4. CloudWatch Logs로 전송
   - Log Group: /aws/eks/erp-dev/application
   - Log Stream: Pod별로 자동 생성

5. API 요청 시 실시간으로 로그 쌓임
   - Pod 재시작해도 로그 유지
   - 영구 보관 (만료 없음)
```

**Lambda 로그:**
```
1. Lambda 함수 실행
2. CloudWatch Logs 자동 전송 (내장 기능)
3. Log Group: /aws/lambda/erp-dev-employee-service
4. Log Stream: 실행마다 자동 생성
```

#### 트러블슈팅 기록

**문제: 로그가 안 쌓임**
```
증상: 마지막 이벤트 시간이 4시간 전에 멈춤

원인: Fluent Bit이 잘못된 Log Group에 쓰려고 시도
- 시도: /aws/eks/erp-dev (틀림)
- 정상: /aws/eks/erp-dev/application (맞음)

해결:
1. helm-chart/values-dev.yaml 수정
   logGroupName: /aws/eks/erp-dev/application

2. Helm 재배포
   helm upgrade --install erp-microservices helm-chart/ -f helm-chart/values-dev.yaml -n erp-dev

3. Fluent Bit 재시작
   kubectl rollout restart daemonset fluent-bit -n amazon-cloudwatch

4. 확인
   kubectl logs -n amazon-cloudwatch fluent-bit-xxxxx --tail=20
   출력: "Created log stream..." 메시지 확인
```

#### Step 2 완료!

CloudWatch Logs 설정이 완료되었습니다.

**달성한 것:**
- EKS Pod 로그 중앙 집중화
- Pod 재시작해도 로그 유지
- 모든 Pod 로그 통합 검색 가능
- Lambda 로그 자동 수집

**다음 단계:**
- Step 3: X-Ray 트레이싱 통합

---

## Step 3: X-Ray 트레이싱 통합 (40분)

### 3-1. 개념 이해: X-Ray가 뭔가요?

**쉽게 설명하면:**
- 마이크로서비스는 여러 서비스가 서로 호출합니다
- 사용자 요청이 어떤 경로로 흘러가는지 추적하는 도구

**예시: 결재 요청 흐름**
```
사용자 → API Gateway → approval-request-service → employee-service (Lambda) → RDS
                              ↓
                       notification-service → Redis
```

**문제:**
- 어느 서비스가 느린지 모름
- 에러가 어디서 발생했는지 모름
- 병목 지점을 찾을 수 없음

**X-Ray 사용 시:**
```
Service Map (시각화):
┌─────────────┐     ┌──────────────┐     ┌──────────┐
│ API Gateway │ →   │ approval-req │ →   │ employee │
│   50ms      │     │    200ms     │     │  150ms   │
└─────────────┘     └──────────────┘     └──────────┘
                            ↓
                    ┌──────────────┐
                    │ notification │
                    │    100ms     │
                    └──────────────┘

→ approval-request-service가 가장 느림 (200ms)
→ 여기를 최적화하면 전체 성능 향상 
```

### 3-2. 실제 예시로 이해하기

**시나리오: 사용자가 "결재 요청" 버튼 클릭**

**Before (X-Ray 없음):**
```
사용자: "왜 이렇게 느려요?"
개발자: "어디가 느린지 모르겠는데요..."
→ 각 서비스 로그 일일이 확인
→ 시간 낭비
```

**After (X-Ray 사용):**
```
X-Ray Service Map 확인:
- API Gateway: 50ms 
- approval-request: 200ms  (느림!)
- employee (Lambda): 150ms 
- notification: 100ms 

→ approval-request-service가 문제
→ 코드 확인 → MongoDB 쿼리 최적화
→ 200ms → 80ms 개선 
```

### 3-3. 구성 요소 4가지

#### ① Spring Boot X-Ray SDK (코드에 추가)

**왜 필요한가?**
- 서비스가 X-Ray에 트레이스를 보내려면 SDK 필요
- 택배 보내려면 택배 상자가 필요한 것과 같음

**설정 내용:**
```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-spring</artifactId>
    <version>2.15.0</version>
</dependency>
```

```java
// XRayConfig.java
@Configuration
public class XRayConfig {
    @Bean
    public Filter TracingFilter() {
        return new AWSXRayServletFilter("approval-request-service");
    }
}
```

**동작 방식:**
```
1. 사용자 요청 들어옴
2. AWSXRayServletFilter가 요청 시작 시간 기록
3. 서비스 처리
4. 요청 종료 시간 기록
5. X-Ray Daemon으로 전송
```

**확인 방법:**
```bash
# 서비스 로그에서 X-Ray 초기화 확인
kubectl logs -n erp-dev -l app=approval-request-service --tail=50 | grep -i xray

# 출력 예시:
# [INFO] AWS X-Ray Recorder initialized
#  X-Ray SDK 정상 동작
```

#### ② X-Ray Daemon (트레이스 수집기)

**왜 필요한가?**
- 서비스가 보낸 트레이스를 AWS X-Ray로 전달
- 우체부가 편지를 수거해서 우체국으로 보내는 것과 같음

**동작 방식:**
```
Service → X-Ray Daemon (UDP 2000) → AWS X-Ray
```

**설정 내용:**
```yaml
# X-Ray DaemonSet
apiVersion: apps/v1
kind: DaemonSet  # 각 Node에 1개씩
metadata:
  name: xray-daemon
  namespace: erp-dev
spec:
  template:
    spec:
      containers:
      - name: xray-daemon
        image: amazon/aws-xray-daemon:latest
        ports:
        - containerPort: 2000
          protocol: UDP
```

**확인 방법:**
```bash
# X-Ray Daemon Pod 확인
kubectl get pods -n erp-dev -l app=xray-daemon

# 출력 예시:
# NAME                READY   STATUS    RESTARTS   AGE
# xray-daemon-xxxxx   1/1     Running   0          10m
# xray-daemon-yyyyy   1/1     Running   0          10m
# → Node 2개이므로 Pod 2개 

# X-Ray Daemon 로그 확인
kubectl logs -n erp-dev -l app=xray-daemon --tail=20

# 출력 예시:
# [Info] Initializing AWS X-Ray daemon 3.6.1
# [Info] Using region: ap-northeast-2
# [Info] Starting proxy http server on 0.0.0.0:2000
#  X-Ray Daemon 정상 실행
```

#### ③ IAM 권한 (X-Ray Daemon이 AWS X-Ray에 쓸 수 있게)

**왜 필요한가?**
- X-Ray Daemon이 AWS X-Ray로 트레이스를 보내려면 권한 필요

**설정 내용:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "xray:PutTraceSegments",      # 트레이스 보내기
      "xray:PutTelemetryRecords"    # 텔레메트리 보내기
    ],
    "Resource": "*"
  }]
}
```

**확인 방법:**
```bash
# IAM 권한 확인
aws iam list-attached-role-policies --role-name erp-dev-eks-node-role --region ap-northeast-2

# 출력에 "XRayDaemonPolicy" 있으면 성공 
```

#### ④ 환경변수 (서비스가 X-Ray Daemon 주소 알게)

**왜 필요한가?**
- 서비스가 X-Ray Daemon에 트레이스를 보내려면 주소 필요
- 편지 보내려면 우체통 위치 알아야 하는 것과 같음

**설정 내용:**
```yaml
# helm-chart/values-dev.yaml
services:
  approvalRequest:
    env:
      - name: AWS_XRAY_DAEMON_ADDRESS
        value: "xray-daemon.erp-dev.svc.cluster.local:2000"
```

**확인 방법:**
```bash
# 서비스 환경변수 확인
kubectl get deployment approval-request-service -n erp-dev \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="AWS_XRAY_DAEMON_ADDRESS")]}'

# 출력 예시:
# {"name":"AWS_XRAY_DAEMON_ADDRESS","value":"xray-daemon.erp-dev.svc.cluster.local:2000"}
#  환경변수 설정됨
```

### 3-4. 실제 트레이스 확인하기

#### 방법 1: AWS Console (웹) - 추천!

```
1. AWS Console 로그인
2. X-Ray 서비스 클릭
3. Service Map 클릭

Service Map (서비스 맵):
┌─────────────┐     ┌──────────────┐     ┌──────────┐
│ API Gateway │ →   │ approval-req │ →   │ employee │
│   50ms      │     │    200ms     │     │  150ms   │
│   100 req   │     │   100 req    │     │  100 req │
│   0% error  │     │   2% error   │     │  0% error│
└─────────────┘     └──────────────┘     └──────────┘

→ approval-request-service에서 2% 에러 발생 
→ 클릭해서 상세 확인

4. Traces 클릭

개별 요청 추적:
Request ID: abc123
Total Duration: 500ms
├─ API Gateway: 50ms
├─ approval-request-service: 200ms
│  ├─ MongoDB query: 150ms  (느림!)
│  └─ Kafka publish: 50ms
├─ employee-service (Lambda): 150ms
└─ notification-service: 100ms

→ MongoDB 쿼리가 병목 지점
→ 인덱스 추가로 최적화 필요
```

#### 방법 2: AWS CLI (터미널)

```bash
# Service Graph 조회
aws xray get-service-graph \
  --start-time $(date -u -d '5 minutes ago' +%s) \
  --end-time $(date -u +%s) \
  --region ap-northeast-2

# Trace 조회
aws xray get-trace-summaries \
  --start-time $(date -u -d '5 minutes ago' +%s) \
  --end-time $(date -u +%s) \
  --region ap-northeast-2
```

### 3-5. 트레이스 생성하기 (테스트)

**중요: X-Ray는 요청이 있어야 트레이스 생성됨**

```bash
# 테스트 요청 보내기
curl https://yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com/api/employees
curl https://yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com/api/approvals

# 1~2분 후 AWS Console → X-Ray → Service Map 확인
# 트레이스가 나타남 
```

### 3-6. 완료 확인 체크리스트

```bash
#  1. X-Ray Daemon Pod 확인
kubectl get pods -n erp-dev -l app=xray-daemon
# 2개 Pod Running 확인

#  2. X-Ray Service 확인
kubectl get svc xray-daemon -n erp-dev
# ClusterIP, UDP 2000 확인

#  3. 서비스 환경변수 확인
kubectl get deployment approval-request-service -n erp-dev \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="AWS_XRAY_DAEMON_ADDRESS")]}'
# xray-daemon.erp-dev.svc.cluster.local:2000 확인

#  4. IAM 권한 확인
aws iam list-attached-role-policies --role-name erp-dev-eks-node-role --region ap-northeast-2 | grep XRay
# XRayDaemonPolicy 확인

#  5. X-Ray Daemon 로그 확인
kubectl logs -n erp-dev -l app=xray-daemon --tail=20
# "Starting proxy http server on 0.0.0.0:2000" 확인

#  6. 테스트 요청 보내기
curl https://yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com/api/employees

#  7. AWS Console → X-Ray → Service Map 확인
# 1~2분 후 트레이스 나타남
```

### 3-7. 왜 이게 중요한가? (실무 관점)

**시나리오 1: 성능 최적화**
```
Before:
- "서비스가 느려요"
- 어디가 느린지 모름
- 전체 코드 리뷰 (시간 낭비)

After:
- X-Ray Service Map 확인
- approval-request-service의 MongoDB 쿼리가 200ms
- 인덱스 추가 → 200ms → 50ms 개선 
```

**시나리오 2: 에러 추적**
```
Before:
- "결재 요청이 안 돼요"
- 어느 서비스에서 에러 났는지 모름
- 모든 서비스 로그 확인 (시간 낭비)

After:
- X-Ray Traces 확인
- employee-service (Lambda)에서 500 에러
- Lambda 로그 확인 → RDS 연결 실패
- RDS Security Group 수정 → 해결 
```

**시나리오 3: 서비스 의존성 파악**
```
X-Ray Service Map:
- approval-request → employee (Lambda)
- approval-request → notification
- approval-processing → Kafka

→ employee-service를 수정하면 approval-request에 영향
→ 배포 전 테스트 필수
```

---

## Step 4: 단일 buildspec.yml 생성 (60분)

### 4-1. 변경 감지 로직 (Git diff)

**왜 필요한가?**
- 현재: 모든 서비스 항상 빌드 (시간 낭비)
- 개선: 변경된 서비스만 빌드 (시간 단축)

### 4-2. 최종 buildspec.yml

```yaml
version: 0.2

env:
  # Parameter Store 통합
  parameter-store:
    AWS_ACCOUNT_ID: /erp/dev/account-id
    AWS_REGION: /erp/dev/region
    EKS_CLUSTER_NAME: /erp/dev/eks/cluster-name
    ECR_REPOSITORY_PREFIX: /erp/dev/ecr/repository-prefix
    PROJECT_NAME: /erp/dev/project-name
    ENVIRONMENT: /erp/dev/environment

phases:
  install:
    commands:
      # Helm 설치
      - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      - helm version
      
      # yq 설치
      - wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
      - chmod +x /usr/local/bin/yq
      
      # kubectl 확인
      - kubectl version --client
  
  pre_build:
    commands:
      # ECR 로그인
      - echo "Logging in to Amazon ECR..."
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
      
      # EKS kubeconfig
      - echo "Updating kubeconfig..."
      - aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
      
      # 변경 감지 (Git diff)
      - echo "Detecting changed services..."
      - |
        if [ -z "$CODEBUILD_WEBHOOK_PREV_COMMIT" ]; then
          echo "First build, building all services"
          CHANGED_SERVICES="approval-request-service approval-processing-service notification-service"
          LAMBDA_CHANGED="false"
        else
          CHANGED_FILES=$(git diff --name-only $CODEBUILD_WEBHOOK_PREV_COMMIT $CODEBUILD_RESOLVED_SOURCE_VERSION)
          echo "Changed files: $CHANGED_FILES"
          
          CHANGED_SERVICES=""
          LAMBDA_CHANGED="false"
          
          if echo "$CHANGED_FILES" | grep -q "backend/employee-service/"; then
            LAMBDA_CHANGED="true"
          fi
          
          if echo "$CHANGED_FILES" | grep -q "backend/approval-request-service/"; then
            CHANGED_SERVICES="$CHANGED_SERVICES approval-request-service"
          fi
          if echo "$CHANGED_FILES" | grep -q "backend/approval-processing-service/"; then
            CHANGED_SERVICES="$CHANGED_SERVICES approval-processing-service"
          fi
          if echo "$CHANGED_FILES" | grep -q "backend/notification-service/"; then
            CHANGED_SERVICES="$CHANGED_SERVICES notification-service"
          fi
          
          if echo "$CHANGED_FILES" | grep -q "helm-chart/"; then
            echo "Helm Chart changed, deploying all EKS services"
            CHANGED_SERVICES="approval-request-service approval-processing-service notification-service"
          fi
        fi
      - echo "Services to build: $CHANGED_SERVICES"
      - echo "Lambda changed: $LAMBDA_CHANGED"
      - export CHANGED_SERVICES
      - export LAMBDA_CHANGED
      
      # 이미지 태그
      - IMAGE_TAG=${CODEBUILD_RESOLVED_SOURCE_VERSION:0:7}
      - echo "Image tag: $IMAGE_TAG"
  
  build:
    commands:
      - echo "Build started on $(date)"
      
      # Lambda (Employee Service)
      - |
        if [ "$LAMBDA_CHANGED" = "true" ]; then
          echo "Building Lambda (Employee Service)..."
          cd backend/employee-service
          
          mvn clean package -DskipTests
          
          docker build -f Dockerfile.lambda -t employee-service-lambda:latest .
          docker tag employee-service-lambda:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:$IMAGE_TAG
          docker tag employee-service-lambda:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:latest
          
          docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:$IMAGE_TAG
          docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:latest
          
          aws lambda update-function-code \
            --function-name $PROJECT_NAME-$ENVIRONMENT-employee-service \
            --image-uri $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/employee-service-lambda:$IMAGE_TAG \
            --region $AWS_REGION
          
          cd ../..
        fi
      
      # EKS 서비스
      - |
        for SERVICE in $CHANGED_SERVICES; do
          echo "Building $SERVICE..."
          cd backend/$SERVICE
          
          mvn clean package -DskipTests
          
          REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/$SERVICE
          docker build -t $REPOSITORY_URI:latest .
          docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
          
          docker push $REPOSITORY_URI:latest
          docker push $REPOSITORY_URI:$IMAGE_TAG
          
          # ECR 이미지 스캔
          aws ecr start-image-scan \
            --repository-name $ECR_REPOSITORY_PREFIX/$SERVICE \
            --image-id imageTag=$IMAGE_TAG \
            --region $AWS_REGION || true
          
          cd ../..
        done
  
  post_build:
    commands:
      # ECR 스캔 결과 확인
      - echo "Checking ECR scan results..."
      - |
        for SERVICE in $CHANGED_SERVICES; do
          echo "Waiting for scan results for $SERVICE..."
          SCAN_STATUS="IN_PROGRESS"
          RETRY_COUNT=0
          MAX_RETRIES=30
          
          while [ "$SCAN_STATUS" = "IN_PROGRESS" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            sleep 10
            SCAN_STATUS=$(aws ecr describe-image-scan-findings \
              --repository-name $ECR_REPOSITORY_PREFIX/$SERVICE \
              --image-id imageTag=$IMAGE_TAG \
              --region $AWS_REGION \
              --query 'imageScanStatus.status' \
              --output text 2>/dev/null || echo "IN_PROGRESS")
            RETRY_COUNT=$((RETRY_COUNT + 1))
          done
          
          if [ "$SCAN_STATUS" = "COMPLETE" ]; then
            CRITICAL=$(aws ecr describe-image-scan-findings \
              --repository-name $ECR_REPOSITORY_PREFIX/$SERVICE \
              --image-id imageTag=$IMAGE_TAG \
              --region $AWS_REGION \
              --query 'imageScanFindings.findingSeverityCounts.CRITICAL' \
              --output text 2>/dev/null || echo "0")
            
            if [ "$CRITICAL" != "None" ] && [ "$CRITICAL" != "0" ]; then
              echo " Critical vulnerabilities found in $SERVICE: $CRITICAL"
              exit 1
            else
              echo " No critical vulnerabilities in $SERVICE"
            fi
          fi
        done
      
      # Helm values 업데이트
      - echo "Updating Helm values..."
      - |
        for SERVICE in $CHANGED_SERVICES; do
          SERVICE_KEY=$(echo $SERVICE | sed 's/-service$//' | sed 's/-\([a-z]\)/\U\1/g' | sed 's/^./\L&/')
          yq eval ".services.$SERVICE_KEY.image.tag = \"$IMAGE_TAG\"" -i helm-chart/values-dev.yaml
          echo "Updated $SERVICE_KEY to $IMAGE_TAG"
        done
      
      # Helm 배포
      - echo "Deploying to EKS with Helm..."
      - |
        helm upgrade --install erp-microservices helm-chart/ \
          -f helm-chart/values-dev.yaml \
          -n erp-dev \
          --create-namespace \
          --wait \
          --timeout 5m
      
      # 배포 확인
      - kubectl get pods -n erp-dev
      - kubectl get svc -n erp-dev
      - helm history erp-microservices -n erp-dev
      
      - echo "Build completed on $(date)"

artifacts:
  files:
    - helm-chart/**/*
  name: helm-chart-$IMAGE_TAG

cache:
  paths:
    - '/root/.m2/**/*'
```

### 4-3. 기존 buildspec.yml 삭제

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project

# 백업
mkdir -p backup-buildspec
cp backend/approval-request-service/buildspec.yml backup-buildspec/ 2>/dev/null || true
cp backend/approval-processing-service/buildspec.yml backup-buildspec/ 2>/dev/null || true
cp backend/notification-service/buildspec.yml backup-buildspec/ 2>/dev/null || true

# 삭제
rm -f backend/approval-request-service/buildspec.yml
rm -f backend/approval-processing-service/buildspec.yml
rm -f backend/notification-service/buildspec.yml
```

### 4-4. 루트에 buildspec.yml 생성

```bash
# 위의 buildspec.yml 내용을 루트에 생성
cat > buildspec.yml << 'EOF'
# (위의 전체 내용)
EOF
```

### 4-5. Git 커밋

```bash
git add buildspec.yml
git add helm-chart/
git rm backend/*/buildspec.yml 2>/dev/null || true
git commit -m "feat: Unified buildspec with 7 CodePipeline features"
git push origin main
```

---

##  완료 체크리스트

### Step 1: Parameter Store
- [ ] Terraform으로 6개 Parameter 생성
- [ ] terraform output 확인
- [ ] CodeBuild Role SSM 권한 확인

### Step 2: CloudWatch Logs
- [ ] CodeBuild CloudWatch Logs 확인 (07단계에서 설정)
- [ ] Fluent Bit DaemonSet 배포
- [ ] CloudWatch Logs 그룹 확인


### Step 3: X-Ray 트레이싱
- [ ] Spring Boot X-Ray SDK 추가 (pom.xml)
- [ ] XRayConfig.java 생성
- [ ] X-Ray DaemonSet 배포
- [ ] Helm Chart X-Ray 환경 변수 추가
- [ ] X-Ray 콘솔에서 Service Map 확인

### Step 4: 단일 buildspec.yml
- [ ] 루트에 buildspec.yml 생성
- [ ] 변경 감지 로직 동작 확인
- [ ] 기존 buildspec.yml 3개 삭제
- [ ] Git 커밋 완료

---

## Step 5: CloudWatch Alarm 추가 (실무 필수) ⭐⭐⭐⭐⭐

### 5-1. 왜 필요한가?

**현재 상황:**
- CloudWatch Logs로 로그 수집 ✅
- X-Ray로 트레이싱 ✅
- **하지만 알림이 없음** ❌

**문제:**
```
ERROR 로그 발생
  ↓
아무도 모름
  ↓
장애 지속
```

**CloudWatch Alarm 추가 시:**
```
ERROR 로그 발생
  ↓
CloudWatch Alarm 감지
  ↓
SNS → Email 알림
  ↓
즉시 대응
```

---

### 5-2. Terraform으로 CloudWatch Alarm 생성

#### 5-2-1. SNS Topic 생성

```bash
cd infrastructure/terraform/dev/erp-dev-CloudWatch
```

**sns.tf 생성:**
```hcl
# SNS Topic for Alarms
resource "aws_sns_topic" "erp_alarms" {
  name = "${var.project_name}-${var.environment}-alarms"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-alarms"
    Environment = var.environment
    Project     = var.project_name
  }
}

# SNS Subscription (Email)
resource "aws_sns_topic_subscription" "erp_alarms_email" {
  topic_arn = aws_sns_topic.erp_alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email  # 이메일 주소
}

output "sns_topic_arn" {
  value = aws_sns_topic.erp_alarms.arn
}
```

**variables.tf 수정:**
```hcl
variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = "your-email@example.com"  # 본인 이메일로 변경
}
```

---

#### 5-2-2. CloudWatch Metric Filter 생성

**log-metric-filters.tf 생성:**
```hcl
# ERROR 로그 카운트 메트릭
resource "aws_cloudwatch_log_metric_filter" "error_logs" {
  name           = "${var.project_name}-${var.environment}-error-count"
  log_group_name = data.terraform_remote_state.eks.outputs.cloudwatch_log_group_name
  
  # ERROR 레벨 로그 패턴
  pattern = "[time, request_id, level = ERROR*, ...]"
  
  metric_transformation {
    name      = "ErrorCount"
    namespace = "ERP/Application"
    value     = "1"
    default_value = 0
  }
}

# Pod 재시작 메트릭
resource "aws_cloudwatch_log_metric_filter" "pod_restarts" {
  name           = "${var.project_name}-${var.environment}-pod-restarts"
  log_group_name = data.terraform_remote_state.eks.outputs.cloudwatch_log_group_name
  
  # Pod 재시작 패턴
  pattern = "[time, stream, log_type = *restart* || log_type = *killed* || log_type = *crash*]"
  
  metric_transformation {
    name      = "PodRestartCount"
    namespace = "ERP/Application"
    value     = "1"
    default_value = 0
  }
}
```

---

#### 5-2-3. CloudWatch Alarm 생성

**alarms.tf 생성:**
```hcl
# ERROR 로그 알람 (5분 동안 10회 이상)
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ErrorCount"
  namespace           = "ERP/Application"
  period              = "300"  # 5분
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "ERROR 로그가 5분 동안 10회 이상 발생"
  treat_missing_data  = "notBreaching"
  
  alarm_actions = [aws_sns_topic.erp_alarms.arn]
  ok_actions    = [aws_sns_topic.erp_alarms.arn]
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-high-error-rate"
    Environment = var.environment
    Severity    = "High"
  }
}

# Pod 재시작 알람 (10분 동안 3회 이상)
resource "aws_cloudwatch_metric_alarm" "pod_restart_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-pod-restarts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "PodRestartCount"
  namespace           = "ERP/Application"
  period              = "600"  # 10분
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "Pod가 10분 동안 3회 이상 재시작"
  treat_missing_data  = "notBreaching"
  
  alarm_actions = [aws_sns_topic.erp_alarms.arn]
  ok_actions    = [aws_sns_topic.erp_alarms.arn]
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-pod-restarts"
    Environment = var.environment
    Severity    = "Critical"
  }
}

# Lambda 에러율 알람 (5분 동안 에러율 5% 이상)
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  threshold           = "5"
  alarm_description   = "Lambda 에러율이 5% 이상"
  treat_missing_data  = "notBreaching"
  
  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate"
    return_data = true
  }
  
  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = "300"
      stat        = "Sum"
      dimensions = {
        FunctionName = "${var.project_name}-${var.environment}-employee-service"
      }
    }
  }
  
  metric_query {
    id = "invocations"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = "300"
      stat        = "Sum"
      dimensions = {
        FunctionName = "${var.project_name}-${var.environment}-employee-service"
      }
    }
  }
  
  alarm_actions = [aws_sns_topic.erp_alarms.arn]
  ok_actions    = [aws_sns_topic.erp_alarms.arn]
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-lambda-error-rate"
    Environment = var.environment
    Severity    = "High"
  }
}
```

---

#### 5-2-4. Remote State 설정

**data.tf 생성:**
```hcl
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "erp-terraform-state-806332783810"
    key    = "dev/erp-dev-EKS/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
```

---

### 5-3. Terraform 실행

```bash
cd infrastructure/terraform/dev/erp-dev-CloudWatch

# 초기화
terraform init

# 계획 확인
terraform plan

# 적용
terraform apply -auto-approve
```

**출력 예시:**
```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

sns_topic_arn = "arn:aws:sns:ap-northeast-2:806332783810:erp-dev-alarms"
```

---

### 5-4. SNS 구독 확인

**이메일 확인:**
1. AWS에서 구독 확인 이메일 발송
2. 이메일 열기
3. "Confirm subscription" 클릭

**확인:**
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:ap-northeast-2:806332783810:erp-dev-alarms \
  --region ap-northeast-2
```

---

### 5-5. 알람 테스트

#### 테스트 1: ERROR 로그 생성

```bash
# Pod에 접속
kubectl exec -it deployment/approval-request-service -n erp-dev -- /bin/sh

# 에러 로그 생성 (Java 애플리케이션 내부에서)
# 또는 간단히 테스트용 에러 로그 출력
for i in {1..15}; do
  echo "$(date) ERROR Test error message $i"
  sleep 1
done
```

**5분 후 이메일 확인:**
```
Subject: ALARM: "erp-dev-high-error-rate" in Asia Pacific (Seoul)

You are receiving this email because your Amazon CloudWatch Alarm 
"erp-dev-high-error-rate" in the Asia Pacific (Seoul) region has 
entered the ALARM state.

Alarm Details:
- State Change: OK -> ALARM
- Reason: Threshold Crossed: 1 datapoint [15.0] was greater than 
  the threshold (10.0).
```

---

#### 테스트 2: Pod 재시작

```bash
# Pod 강제 삭제 (재시작 유발)
kubectl delete pod -l app=approval-request-service -n erp-dev

# 3번 반복
kubectl delete pod -l app=approval-processing-service -n erp-dev
kubectl delete pod -l app=notification-service -n erp-dev
```

**10분 후 이메일 확인:**
```
Subject: ALARM: "erp-dev-pod-restarts" in Asia Pacific (Seoul)

Alarm Details:
- State Change: OK -> ALARM
- Reason: Threshold Crossed: 1 datapoint [3.0] was greater than 
  the threshold (3.0).
```

---

### 5-6. CloudWatch Console 확인

**Alarms 확인:**
```bash
# 브라우저에서
https://ap-northeast-2.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#alarmsV2:
```

**확인 항목:**
- erp-dev-high-error-rate: OK 상태
- erp-dev-pod-restarts: OK 상태
- erp-dev-lambda-error-rate: OK 상태

---

### 5-7. 면접 어필 포인트

**Q: 모니터링은 어떻게 하나요?**

**A:**
"3단계로 모니터링합니다. 첫째, CloudWatch Logs로 모든 Pod 로그를 중앙 집중합니다. 둘째, CloudWatch Alarm으로 ERROR 로그가 5분 동안 10회 이상 발생하거나 Pod가 10분 동안 3회 이상 재시작하면 SNS로 이메일 알림을 받습니다. 셋째, X-Ray로 서비스 간 트레이싱을 추적하여 병목 지점을 파악합니다."

**Q: 장애 발생 시 어떻게 대응하나요?**

**A:**
"CloudWatch Alarm이 이메일로 알림을 보내면, CloudWatch Logs Insights로 에러 로그를 검색하여 원인을 파악합니다. X-Ray Service Map에서 어느 서비스에서 지연이 발생했는지 확인하고, kubectl logs로 상세 로그를 확인합니다. 문제 해결 후 Alarm이 자동으로 OK 상태로 돌아갑니다."

---

##  완료 체크리스트

### CGV vs ERP 비교

| 기능 | CGV (GitLab CI) | ERP (CodePipeline) | 차별화 포인트 |
|------|----------------|-------------------|--------------|
| Secret 관리 | GitLab Variables |  AWS Secrets Manager | RDS 자동 로테이션 |
| 설정 관리 | .gitlab-ci.yml 하드코딩 |  Parameter Store | 중앙 관리, 환경별 분리 |
| 로그 관리 | GitLab Logs |  CloudWatch Logs | 영구 보관, 통합 검색 |
| **알림 관리** | **수동** | ** CloudWatch Alarm + SNS** | **실시간 이메일 알림** |
| 이미지 스캔 | 수동 |  ECR 자동 스캔 | Critical 발견 시 배포 중단 |
| 트레이싱 | 없음 |  X-Ray | Service Map, 병목 분석 |
| 변경 감지 | 전체 빌드 |  Git diff | 변경된 서비스만 빌드 |
| 배포 방식 | kubectl set image |  helm upgrade | Manifests 자동 반영 |

**결론: CodePipeline의 AWS 네이티브 통합을 최대한 활용하여 CGV 수준 초과 달성!**

---

##  다음 단계

**06단계 완료!**

**다음 파일을 읽으세요:**
→ **07_CODEPIPELINE.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 07_CODEPIPELINE.md
```

---

**"7가지 CodePipeline 강점을 모두 구현했습니다. 이제 CGV와 대등한 수준입니다!"**
