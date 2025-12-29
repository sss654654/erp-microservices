# 06. buildspec.yml 작성 (CodePipeline 강점 극대화)

**소요 시간**: 4시간  
**목표**: CloudWatch Logs, X-Ray, CloudWatch Alarm 구축 완료

---

## 📋 목차

1. [Step 1: Parameter Store 활용](#step-1-parameter-store-활용)
2. [Step 2: CloudWatch Logs 중앙 집중](#step-2-cloudwatch-logs-중앙-집중)
3. [Step 3: X-Ray 트레이싱 통합](#step-3-x-ray-트레이싱-통합)
4. [Step 4: CloudWatch Alarm 추가](#step-4-cloudwatch-alarm-추가)
5. [실제 동작 시나리오](#실제-동작-시나리오)

---

## Step 1: Parameter Store 활용 (20분)

### 1-1. 왜 필요한가?

**Before (하드코딩):**
```yaml
env:
  variables:
    AWS_ACCOUNT_ID: "806332783810"
    EKS_CLUSTER_NAME: "erp-dev"
```

**After (Parameter Store):**
```yaml
env:
  parameter-store:
    AWS_ACCOUNT_ID: /erp/dev/account-id
    EKS_CLUSTER_NAME: /erp/dev/eks/cluster-name
```

### 1-2. Terraform으로 생성

```bash
cd infrastructure/terraform/dev/erp-dev-ParameterStore
terraform init
terraform apply -auto-approve
```

**생성된 6개 Parameter:**
- `/erp/dev/account-id` - AWS Account ID
- `/erp/dev/region` - ap-northeast-2
- `/erp/dev/eks/cluster-name` - erp-dev
- `/erp/dev/ecr/repository-prefix` - erp
- `/erp/dev/project-name` - erp
- `/erp/dev/environment` - dev

**확인:**
```bash
aws ssm get-parameter --name /erp/dev/eks/cluster-name --region ap-northeast-2
```

---

## Step 2: CloudWatch Logs 중앙 집중 (30분)

### 2-1. 개념: CloudWatch Logs란?

**문제:**
```
Pod 재시작 → 로그 사라짐
Pod 10개 → 각각 확인해야 함
```

**해결:**
```
Pod → Fluent Bit → CloudWatch Logs
→ 영구 보관
→ 통합 검색
```

### 2-2. 구성 요소

#### ① IAM 권한 (EKS Node → CloudWatch)

**Terraform 코드:**
```hcl
# infrastructure/terraform/dev/erp-dev-IAM/eks-node-role/eks-node-role.tf
resource "aws_iam_role_policy" "eks_node_cloudwatch_logs" {
  role = aws_iam_role.eks_node.name
  name = "eks-node-cloudwatch-logs-policy"

  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = "arn:aws:logs:*:*:log-group:/aws/eks/erp-dev/*"
    }]
  })
}
```

#### ② Fluent Bit DaemonSet

**Helm Chart:**
```yaml
# helm-chart/templates/fluent-bit.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: amazon-cloudwatch
spec:
  template:
    spec:
      containers:
      - name: fluent-bit
        image: amazon/aws-for-fluent-bit:2.31.12
        env:
        - name: AWS_REGION
          value: ap-northeast-2
        - name: LOG_GROUP_NAME
          value: /aws/eks/erp-dev/application
```

**배포:**
```bash
helm upgrade --install erp-microservices helm-chart/ \
  -f helm-chart/values-dev.yaml -n erp-dev
```

#### ③ CloudWatch Log Group

**자동 생성:**
```
/aws/eks/erp-dev/application
├── approval-request-service-xxx (Log Stream)
├── approval-processing-service-xxx
├── notification-service-xxx
└── kafka-xxx
```

### 2-3. 확인 방법

```bash
# 1. Fluent Bit Pod 확인
kubectl get pods -n amazon-cloudwatch
# fluent-bit-xxxxx   1/1     Running

# 2. Log Group 확인
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/erp-dev \
  --region ap-northeast-2

# 3. 실제 로그 확인
aws logs tail /aws/eks/erp-dev/application --since 5m --region ap-northeast-2
```

---

## Step 3: X-Ray 트레이싱 통합 (60분)

### 3-1. 개념: X-Ray란?

**문제:**
```
사용자: "왜 느려요?"
개발자: "어디가 느린지 모르겠는데요..."
```

**해결:**
```
X-Ray Service Map:
클라이언트 → approval-request (1.2초) → MongoDB (0.8초)
                    ↓
              employee (Lambda, 0.03초)
```

### 3-2. 구성 요소

#### ① Spring Boot X-Ray SDK

**pom.xml:**
```xml
<dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-spring</artifactId>
    <version>2.15.0</version>
</dependency>
```

**XRayConfig.java:**
```java
@Configuration
public class XRayConfig {
    
    private static final Logger logger = LoggerFactory.getLogger(XRayConfig.class);
    
    @PostConstruct
    public void init() {
        logger.info("=== X-Ray Configuration Initializing ===");
        AWSXRayRecorderBuilder builder = AWSXRayRecorderBuilder.standard();
        AWSXRay.setGlobalRecorder(builder.build());
        logger.info("=== X-Ray Recorder Initialized Successfully ===");
    }
    
    @Bean
    public Filter TracingFilter() {
        logger.info("=== X-Ray Servlet Filter Created ===");
        return new AWSXRayServletFilter("approval-request-service");
    }
}
```

**적용 서비스:**
- ✅ approval-request-service
- ✅ approval-processing-service
- ✅ notification-service

#### ② X-Ray DaemonSet

**Helm Chart:**
```yaml
# helm-chart/templates/xray-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
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

#### ③ 환경변수 설정

**Helm values-dev.yaml:**
```yaml
services:
  approvalRequest:
    env:
      - name: AWS_XRAY_DAEMON_ADDRESS
        value: "xray-daemon.erp-dev.svc.cluster.local:2000"
```

#### ④ Lambda X-Ray 활성화

```bash
# Lambda X-Ray 활성화
aws lambda update-function-configuration \
  --function-name erp-dev-employee-service \
  --tracing-config Mode=Active \
  --region ap-northeast-2

# Lambda Role에 X-Ray 권한 추가
aws iam attach-role-policy \
  --role-name erp-dev-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess \
  --region ap-northeast-2
```

### 3-3. X-Ray 추적 범위

#### ✅ **추적 가능 (HTTP 기반)**

**1. approval-request-service (EKS)**
```
클라이언트 → approval-request-service (HTTP)
→ X-Ray Servlet Filter 자동 추적
```

**2. employee-service (Lambda)**
```
클라이언트 → employee-service (Lambda)
→ Lambda X-Ray 자동 추적
```

#### ❌ **추적 불가 (Kafka 기반)**

**approval-processing-service**
```
Kafka Consumer만 있음 (HTTP 요청 없음)
→ X-Ray Servlet Filter 작동 안 함
→ CloudWatch Logs로 모니터링
```

### 3-4. 확인 방법

```bash
# 1. X-Ray Daemon Pod 확인
kubectl get pods -n erp-dev -l app=xray-daemon
# xray-daemon-xxxxx   1/1     Running

# 2. 서비스 X-Ray 초기화 확인
kubectl logs -n erp-dev -l app=approval-request-service | grep "X-Ray"
# === X-Ray Configuration Initializing ===
# === X-Ray Recorder Initialized Successfully ===

# 3. 트레이스 전송 확인
kubectl logs -n erp-dev -l app=xray-daemon --tail=20
# [Info] Successfully sent batch of 1 segments (0.022 seconds)

# 4. Lambda 트레이스 확인
aws logs tail /aws/lambda/erp-dev-employee-service --since 5m --region ap-northeast-2 | grep XRAY
# XRAY TraceId: 1-6952584e-7b19e7a122a262d54b7e5296
```

---

## Step 4: CloudWatch Alarm 추가 (30분)

### 4-1. 왜 필요한가?

**문제:**
```
ERROR 로그 발생 → 아무도 모름 → 장애 지속
```

**해결:**
```
ERROR 로그 발생 → CloudWatch Alarm → SNS → 이메일 알림
```

### 4-2. Terraform으로 생성

```bash
cd infrastructure/terraform/dev/erp-dev-CloudWatch
terraform init
terraform apply -auto-approve
```

**생성된 리소스:**
- SNS Topic: `erp-dev-alarms`
- Email Subscription: `subinhong0109@dankook.ac.kr`
- Metric Filter: ERROR 로그 카운트
- Metric Filter: Pod 재시작 감지
- Alarm: ERROR 10회 이상 (5분)
- Alarm: Pod 재시작 3회 이상 (10분)
- Alarm: Lambda 에러율 5% 이상

### 4-3. 이메일 구독 확인

```
1. AWS에서 이메일 발송
2. "AWS Notification - Subscription Confirmation" 이메일 열기
3. "Confirm subscription" 클릭
```

### 4-4. 테스트

```bash
# Pod 재시작 유발
kubectl delete pods -n erp-dev -l app=approval-request-service

# 2분 후 이메일 확인
# Subject: ALARM: "erp-dev-pod-restarts" in Asia Pacific (Seoul)
# Threshold Crossed: 3 restarts detected
```

---

## 🎯 실제 동작 시나리오

### 시나리오 1: 정상 요청 (GET /api/approvals)

```bash
curl https://yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com/api/approvals
```

**1. X-Ray 추적 (approval-request-service)**
```
① 요청 들어옴
② AWSXRayServletFilter가 Segment 생성
③ 서비스 처리 (MongoDB 쿼리)
④ Segment 종료 (응답 시간 기록)
⑤ X-Ray Daemon으로 전송 (UDP 2000)
⑥ X-Ray Daemon → AWS X-Ray 서비스
```

**확인:**
```bash
kubectl logs -n erp-dev -l app=xray-daemon --tail=5
# [Info] Successfully sent batch of 1 segments (0.022 seconds)
```

**AWS Console:**
```
X-Ray → Traces
→ Trace ID: 1-6952584e-xxx
→ Duration: 1.2초
→ Status: 200 OK
```

**2. CloudWatch Logs 수집**
```
① Pod가 stdout으로 로그 출력
   2025-12-29T10:00:00 INFO Received request: GET /api/approvals
② Kubernetes가 /var/log/containers/*.log에 저장
③ Fluent Bit이 로그 읽음
④ CloudWatch Logs로 전송
⑤ /aws/eks/erp-dev/application에 저장
```

**확인:**
```bash
aws logs tail /aws/eks/erp-dev/application --since 1m --region ap-northeast-2
# 2025-12-29T10:00:00 INFO Received request: GET /api/approvals
```

**3. CloudWatch Alarm (정상)**
```
① Metric Filter가 로그 스캔
② ERROR 패턴 없음
③ Alarm 상태: OK
```

---

### 시나리오 2: 에러 발생 (500 Internal Server Error)

```bash
# MongoDB 연결 실패 시나리오
```

**1. CloudWatch Logs 수집**
```
① Pod가 ERROR 로그 출력
   2025-12-29T10:05:00 ERROR MongoTimeoutException: Connection timeout
② Fluent Bit이 로그 수집
③ CloudWatch Logs에 저장
```

**2. CloudWatch Alarm 발동**
```
① Metric Filter가 "ERROR" 패턴 감지
② ErrorCount 메트릭 증가 (1 → 2 → ... → 11)
③ 5분 동안 10회 초과
④ Alarm 상태: OK → ALARM
⑤ SNS Topic으로 알림 발송
⑥ 이메일 수신
```

**이메일 내용:**
```
Subject: ALARM: "erp-dev-high-error-rate" in Asia Pacific (Seoul)

Alarm Details:
- State Change: OK -> ALARM
- Reason: Threshold Crossed: 11 errors in 5 minutes
- Timestamp: 2025-12-29 10:10:00 KST
```

**3. X-Ray 추적 (에러 포함)**
```
① 요청 들어옴
② 서비스 처리 중 Exception 발생
③ Segment에 에러 정보 기록
   - HasError: true
   - Exception: MongoTimeoutException
④ X-Ray로 전송
```

**AWS Console:**
```
X-Ray → Traces → Filter: http.status = 500
→ Trace ID: 1-xxx
→ Duration: 0.5초
→ Status: 500 Internal Server Error
→ Exception: MongoTimeoutException
```

---

### 시나리오 3: Lambda 호출 (GET /api/employees)

```bash
curl https://yvx3l9ifii.execute-api.ap-northeast-2.amazonaws.com/api/employees
```

**1. Lambda X-Ray 추적**
```
① API Gateway → Lambda 호출
② Lambda Runtime이 자동으로 Segment 생성
③ Lambda 함수 실행
   - RDS 쿼리: 20ms
   - 응답 생성: 11ms
④ Segment 종료 (총 31ms)
⑤ AWS X-Ray로 직접 전송 (EKS Daemon 거치지 않음)
```

**확인:**
```bash
# Lambda 로그에서 TraceId 확인
aws logs tail /aws/lambda/erp-dev-employee-service --since 1m --region ap-northeast-2
# XRAY TraceId: 1-6952584e-7b19e7a122a262d54b7e5296
```

**AWS Console:**
```
X-Ray → Traces
→ Service: erp-dev-employee-service
→ Type: AWS::Lambda
→ Duration: 0.031초 (31ms)
→ Memory Used: 348 MB / 2048 MB
→ Cold Start: No
```

**2. Lambda CloudWatch Logs**
```
① Lambda가 자동으로 /aws/lambda/erp-dev-employee-service에 로그 전송
② Fluent Bit 불필요 (Lambda 내장 기능)
```

---

### 시나리오 4: Kafka 메시지 처리 (approval-processing-service)

```
approval-request → Kafka → approval-processing
```

**1. X-Ray 추적 (불가)**
```
❌ HTTP 요청 없음 (Kafka Consumer만)
❌ X-Ray Servlet Filter 작동 안 함
→ CloudWatch Logs로 대체
```

**2. CloudWatch Logs 수집**
```
① approval-processing-service가 Kafka 메시지 수신
   2025-12-29T10:00:00 INFO Received approval request: requestId=123
② Fluent Bit이 로그 수집
③ CloudWatch Logs에 저장
```

**확인:**
```bash
aws logs tail /aws/eks/erp-dev/application --since 1m --region ap-northeast-2 | grep "approval-processing"
# 2025-12-29T10:00:00 INFO Received approval request: requestId=123
```

---

## 📊 모니터링 구조 요약

### ✅ **HTTP 기반 서비스**

| 서비스 | X-Ray | CloudWatch Logs | CloudWatch Alarm |
|--------|-------|-----------------|------------------|
| approval-request-service | ✅ | ✅ | ✅ |
| employee-service (Lambda) | ✅ | ✅ | ✅ |

**동작:**
- HTTP 요청 → X-Ray Servlet Filter → 트레이스 생성
- 로그 출력 → Fluent Bit → CloudWatch Logs
- ERROR 로그 → Metric Filter → Alarm → 이메일

### ⚠️ **Kafka 기반 서비스**

| 서비스 | X-Ray | CloudWatch Logs | CloudWatch Alarm |
|--------|-------|-----------------|------------------|
| approval-processing-service | ❌ | ✅ | ✅ |
| notification-service | ❌ | ✅ | ✅ |

**동작:**
- Kafka 메시지 → X-Ray 추적 불가
- 로그 출력 → Fluent Bit → CloudWatch Logs
- ERROR 로그 → Metric Filter → Alarm → 이메일

---

## 🎓 면접 어필 포인트

### Q: 모니터링은 어떻게 구축했나요?

**A:** "3단계로 구축했습니다. 첫째, CloudWatch Logs로 모든 Pod 로그를 Fluent Bit DaemonSet을 통해 중앙 집중했습니다. 둘째, X-Ray로 HTTP 기반 서비스의 분산 트레이싱을 구현했습니다. approval-request-service는 X-Ray Servlet Filter로, employee-service Lambda는 Lambda 내장 X-Ray로 추적합니다. 셋째, CloudWatch Alarm으로 ERROR 로그 10회 이상 또는 Pod 재시작 3회 이상 시 SNS 이메일 알림을 받습니다."

### Q: Kafka 서비스는 왜 X-Ray 추적이 안 되나요?

**A:** "X-Ray Servlet Filter는 HTTP 요청만 자동 추적합니다. approval-processing-service는 Kafka Consumer만 있어서 HTTP 요청이 없습니다. 이런 경우 CloudWatch Logs로 모니터링하며, 필요 시 Kafka 메시지에 Trace ID를 수동으로 전파하는 방식을 고려할 수 있습니다. 실무에서는 HTTP 기반은 X-Ray, 메시징 기반은 CloudWatch Logs를 함께 사용하는 하이브리드 전략이 일반적입니다."

### Q: CloudWatch Logs와 X-Ray의 차이는?

**A:** "CloudWatch Logs는 '무엇이' 잘못되었는지 파악하는 도구이고, X-Ray는 '어디가' 느린지 파악하는 도구입니다. CloudWatch Logs로 ERROR 로그를 검색하여 문제를 찾고, X-Ray Service Map으로 병목 지점을 찾아 성능을 최적화합니다. 예를 들어 CloudWatch Logs에서 'MongoTimeoutException'을 발견하고, X-Ray에서 MongoDB 쿼리가 0.8초 걸리는 것을 확인하여 인덱스를 추가했습니다."

---

## ✅ 완료 체크리스트

### Terraform
- [x] Parameter Store 6개 생성
- [x] CloudWatch Alarm 3개 생성 (SNS + Metric Filter)
- [x] EKS Node Role에 CloudWatch Logs 권한 추가
- [x] Lambda Role에 X-Ray 권한 추가

### Helm Chart
- [x] Fluent Bit DaemonSet 배포
- [x] X-Ray DaemonSet 배포
- [x] 모든 서비스에 AWS_XRAY_DAEMON_ADDRESS 환경변수 설정

### 코드
- [x] 3개 서비스에 XRayConfig.java 추가 (로깅 포함)
- [x] pom.xml에 aws-xray-recorder-sdk-spring 추가

### Lambda
- [x] Lambda X-Ray Active 모드 활성화
- [x] Lambda Role에 AWSXRayDaemonWriteAccess 정책 추가

### 검증
- [x] Fluent Bit Pod Running 확인
- [x] X-Ray Daemon Pod Running 확인
- [x] CloudWatch Logs에 로그 수집 확인
- [x] X-Ray Traces 수집 확인 (EKS + Lambda)
- [x] CloudWatch Alarm 이메일 수신 확인

---

## 🚀 다음 단계

**06단계 완료!**

**다음 파일을 읽으세요:**
→ **07_CODEPIPELINE.md**

```bash
cd /mnt/c/Users/Lethe/Desktop/취업준비/erp-project/re_build
cat 07_CODEPIPELINE.md
```

---

**"CloudWatch Logs, X-Ray, CloudWatch Alarm 모두 구축 완료! 이제 완벽한 모니터링 체계를 갖췄습니다!"** 🎉
