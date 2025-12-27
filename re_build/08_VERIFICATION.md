# 08. 검증 및 테스트

**소요 시간**: 1시간  
**목표**: 전체 시스템 동작 확인, 롤백 테스트, 문제 해결

---

##  검증 체크리스트

### Phase 1: Helm 배포 확인 (15분)
### Phase 2: Kubernetes 리소스 확인 (15분)
### Phase 3: API Gateway 테스트 (15분)
### Phase 4: 롤백 테스트 (10분)
### Phase 5: 최종 확인 (5분)

---

##  Phase 1: Helm 배포 확인 (15분)

### 1-1. Helm Release 확인

```bash
# Helm Release 목록
helm list -n erp-dev

# 예상 출력:
# NAME                NAMESPACE  REVISION  UPDATED                                STATUS    CHART                      APP VERSION
# erp-microservices   erp-dev    1         2024-12-27 17:30:00.123456 +0900 KST   deployed  erp-microservices-0.1.0    1.0.0
```

**확인 사항:**
-  STATUS가 `deployed`
-  REVISION이 1 이상
-  CHART 이름이 `erp-microservices-0.1.0`

### 1-2. Helm 히스토리 확인

```bash
# 배포 히스토리
helm history erp-microservices -n erp-dev

# 예상 출력:
# REVISION  UPDATED                   STATUS      CHART                      APP VERSION  DESCRIPTION
# 1         2024-12-27 17:30:00 KST   deployed    erp-microservices-0.1.0    1.0.0        Install complete
```

**확인 사항:**
-  최소 1개 이상의 REVISION
-  최신 REVISION의 STATUS가 `deployed`

### 1-3. Helm Values 확인

```bash
# 현재 적용된 values 확인
helm get values erp-microservices -n erp-dev

# 예상 출력:
# USER-SUPPLIED VALUES:
# namespace: erp-dev
# services:
#   approvalRequest:
#     image:
#       tag: a1b2c3d  # Git 커밋 해시
#   employee:
#     image:
#       tag: a1b2c3d
#   ...
```

**확인 사항:**
-  image.tag가 Git 커밋 해시 (7자리)
-  namespace가 `erp-dev`
-  4개 서비스 모두 설정됨

---

##  Phase 2: Kubernetes 리소스 확인 (15분)

### 2-1. Pod 상태 확인

```bash
# Pod 목록
kubectl get pods -n erp-dev

# 예상 출력:
# NAME                                        READY   STATUS    RESTARTS   AGE
# approval-processing-service-xxx             1/1     Running   0          5m
# approval-processing-service-yyy             1/1     Running   0          5m
# approval-request-service-xxx                1/1     Running   0          5m
# approval-request-service-yyy                1/1     Running   0          5m
# employee-service-xxx                        1/1     Running   0          5m
# employee-service-yyy                        1/1     Running   0          5m
# notification-service-xxx                    1/1     Running   0          5m
# notification-service-yyy                    1/1     Running   0          5m
# kafka-xxx                                   1/1     Running   0          5m
# zookeeper-xxx                               1/1     Running   0          5m
```

**확인 사항:**
-  모든 Pod가 `Running` 상태
-  READY가 `1/1`
-  RESTARTS가 0 또는 낮은 숫자
-  총 10개 Pod (서비스 8개 + Kafka + Zookeeper)

**문제 발생 시:**
```bash
# Pod 상세 확인
kubectl describe pod <pod-name> -n erp-dev

# Pod 로그 확인
kubectl logs <pod-name> -n erp-dev --tail=50
```

### 2-2. Service 확인

```bash
# Service 목록
kubectl get svc -n erp-dev

# 예상 출력:
# NAME                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
# approval-processing-service   ClusterIP   10.100.xxx.xxx   <none>        8083/TCP   5m
# approval-request-service      ClusterIP   10.100.xxx.xxx   <none>        8082/TCP   5m
# employee-service              ClusterIP   10.100.xxx.xxx   <none>        8081/TCP   5m
# notification-service          ClusterIP   10.100.xxx.xxx   <none>        8084/TCP   5m
# kafka                         ClusterIP   10.100.xxx.xxx   <none>        9092/TCP   5m
# zookeeper                     ClusterIP   10.100.xxx.xxx   <none>        2181/TCP   5m
```

**확인 사항:**
-  모든 Service가 `ClusterIP` (LoadBalancer 없음)
-  PORT(S)가 올바름 (8081, 8082, 8083, 8084, 9092, 2181)
-  EXTERNAL-IP가 `<none>` (내부 통신만)

**️ 중요: LoadBalancer 타입이 있으면 문제!**
```bash
# LoadBalancer 타입 확인
kubectl get svc -n erp-dev -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}'

# 출력이 없어야 정상
# 만약 notification-service가 나오면:
kubectl delete svc notification-service -n erp-dev
helm upgrade --install erp-microservices helm-chart/ -f helm-chart/values-dev.yaml -n erp-dev
```

### 2-3. TargetGroupBinding 확인

```bash
# TargetGroupBinding 목록
kubectl get targetgroupbinding -n erp-dev

# 예상 출력:
# NAME                                  SERVICE-NAME                  SERVICE-PORT   TARGET-TYPE   AGE
# approval-processing-service-tgb       approval-processing-service   8083           ip            5m
# approval-request-service-tgb          approval-request-service      8082           ip            5m
# employee-service-tgb                  employee-service              8081           ip            5m
# notification-service-tgb              notification-service          8084           ip            5m
```

**확인 사항:**
-  4개 TargetGroupBinding 존재
-  SERVICE-NAME이 올바름
-  SERVICE-PORT가 올바름
-  TARGET-TYPE이 `ip`

**상세 확인:**
```bash
# TargetGroupBinding 상세
kubectl describe targetgroupbinding employee-service-tgb -n erp-dev

# 예상 출력:
# Status:
#   Observed Generation:  1
# Events:
#   Type    Reason                Age   From                Message
#   ----    ------                ----  ----                -------
#   Normal  SuccessfullyReconciled  5m   targetGroupBinding  Successfully reconciled
```

### 2-4. HPA 확인

```bash
# HPA 목록
kubectl get hpa -n erp-dev

# 예상 출력:
# NAME                              REFERENCE                                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
# approval-processing-service-hpa   Deployment/approval-processing-service   10%/70%   2         3         2          5m
# approval-request-service-hpa      Deployment/approval-request-service      15%/70%   2         3         2          5m
# employee-service-hpa              Deployment/employee-service              12%/70%   2         3         2          5m
# notification-service-hpa          Deployment/notification-service          8%/70%    2         3         2          5m
```

**확인 사항:**
-  4개 HPA 존재
-  MINPODS가 2
-  MAXPODS가 3
-  REPLICAS가 2 (현재 Pod 수)
-  TARGETS가 70% 미만 (정상)

### 2-5. 이미지 태그 확인

```bash
# Deployment 이미지 확인
kubectl get deployment -n erp-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'

# 예상 출력:
# approval-processing-service  806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-processing-service:a1b2c3d
# approval-request-service     806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/approval-request-service:a1b2c3d
# employee-service             806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service:a1b2c3d
# notification-service         806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/notification-service:a1b2c3d
# kafka                        confluentinc/cp-kafka:7.5.0
# zookeeper                    confluentinc/cp-zookeeper:7.5.0
```

**확인 사항:**
-  4개 서비스 이미지 태그가 Git 커밋 해시 (7자리)
-  Kafka, Zookeeper 이미지가 올바름
-  `:latest` 태그가 없음

---

##  Phase 3: API Gateway 테스트 (15분)

### 3-1. NLB Target Health 확인

**AWS Console:**
1. EC2 → Load Balancers
2. `erp-dev-nlb` 선택
3. Target Groups 탭
4. 4개 Target Group 확인:
   - `erp-dev-employee-nlb-tg`
   - `erp-dev-approval-req-nlb-tg`
   - `erp-dev-approval-proc-nlb-tg`
   - `erp-dev-notification-nlb-tg`
5. 각 Target Group의 Targets 탭
6. Health status가 `healthy` 확인

**AWS CLI:**
```bash
# Target Group ARN 목록
aws elbv2 describe-target-groups \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-northeast-2:806332783810:loadbalancer/net/erp-dev-nlb/xxx \
  --region ap-northeast-2 \
  --query 'TargetGroups[*].[TargetGroupName,TargetGroupArn]' \
  --output table

# Target Health 확인 (각 Target Group)
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-2:806332783810:targetgroup/erp-dev-employee-nlb-tg/xxx \
  --region ap-northeast-2 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

# 예상 출력:
# --------------------------------
# |  DescribeTargetHealth        |
# +----------------+--------------+
# |  10.0.10.xxx   |  healthy     |
# |  10.0.11.xxx   |  healthy     |
# +----------------+--------------+
```

**확인 사항:**
-  4개 Target Group 모두 존재
-  각 Target Group에 2개 Target (Pod IP)
-  모든 Target의 State가 `healthy`

### 3-2. API Gateway 엔드포인트 테스트

**API Gateway URL 확인:**
```bash
# Terraform output에서 확인
cd infrastructure/terraform/dev/erp-dev-APIGateway
terraform output api_gateway_url

# 예상 출력:
# https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com
```

**Employee Service 테스트:**
```bash
# 직원 목록 조회
curl https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/api/employees

# 예상 출력:
# [
#   {
#     "id": 1,
#     "name": "홍길동",
#     "email": "hong@erp.com",
#     "department": "DEVELOPMENT"
#   },
#   ...
# ]
```

**Approval Request Service 테스트:**
```bash
# 결재 요청 목록 조회
curl https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/api/approvals

# 예상 출력:
# [
#   {
#     "requestId": 1,
#     "requesterId": 1,
#     "title": "연차 신청",
#     "status": "PENDING"
#   },
#   ...
# ]
```

**확인 사항:**
-  HTTP 200 응답
-  JSON 형식 응답
-  데이터가 올바름

**문제 발생 시:**
```bash
# 502 Bad Gateway: NLB Target이 unhealthy
# 503 Service Unavailable: Pod가 Running이 아님
# 504 Gateway Timeout: Pod 응답 시간 초과

# Pod 로그 확인
kubectl logs -n erp-dev -l app=employee-service --tail=50
```

---

##  Phase 4: 롤백 테스트 (10분)

### 4-1. 현재 Revision 확인

```bash
# Helm 히스토리
helm history erp-microservices -n erp-dev

# 예상 출력:
# REVISION  UPDATED                   STATUS      CHART                      APP VERSION  DESCRIPTION
# 1         2024-12-27 17:30:00 KST   superseded  erp-microservices-0.1.0    1.0.0        Install complete
# 2         2024-12-27 17:35:00 KST   deployed    erp-microservices-0.1.0    1.0.0        Upgrade complete
```

### 4-2. 이전 Revision으로 롤백

```bash
# Revision 1로 롤백
helm rollback erp-microservices 1 -n erp-dev

# 예상 출력:
# Rollback was a success! Happy Helming!
```

**확인:**
```bash
# Pod 재시작 확인
kubectl get pods -n erp-dev -w

# 이미지 태그 확인 (이전 커밋 해시로 변경됨)
kubectl get deployment -n erp-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'

# Helm 히스토리 확인 (Revision 3 생성됨)
helm history erp-microservices -n erp-dev

# 예상 출력:
# REVISION  UPDATED                   STATUS      CHART                      APP VERSION  DESCRIPTION
# 1         2024-12-27 17:30:00 KST   superseded  erp-microservices-0.1.0    1.0.0        Install complete
# 2         2024-12-27 17:35:00 KST   superseded  erp-microservices-0.1.0    1.0.0        Upgrade complete
# 3         2024-12-27 17:40:00 KST   deployed    erp-microservices-0.1.0    1.0.0        Rollback to 1
```

### 4-3. 최신 Revision으로 복구

```bash
# Revision 2로 다시 롤백
helm rollback erp-microservices 2 -n erp-dev

# 확인
helm history erp-microservices -n erp-dev
```

**확인 사항:**
-  롤백 명령 성공
-  Pod가 재시작됨
-  이미지 태그가 변경됨
-  Helm 히스토리에 새 Revision 추가됨
-  API Gateway 테스트 성공

---

##  Phase 5: 최종 확인 (5분)

### 5-1. 전체 시스템 상태

```bash
# 모든 리소스 확인
kubectl get all -n erp-dev

# 예상 출력:
# NAME                                            READY   STATUS    RESTARTS   AGE
# pod/approval-processing-service-xxx             1/1     Running   0          10m
# pod/approval-request-service-xxx                1/1     Running   0          10m
# pod/employee-service-xxx                        1/1     Running   0          10m
# pod/notification-service-xxx                    1/1     Running   0          10m
# pod/kafka-xxx                                   1/1     Running   0          10m
# pod/zookeeper-xxx                               1/1     Running   0          10m
#
# NAME                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
# service/approval-processing-service   ClusterIP   10.100.xxx.xxx   <none>        8083/TCP   10m
# service/approval-request-service      ClusterIP   10.100.xxx.xxx   <none>        8082/TCP   10m
# service/employee-service              ClusterIP   10.100.xxx.xxx   <none>        8081/TCP   10m
# service/notification-service          ClusterIP   10.100.xxx.xxx   <none>        8084/TCP   10m
# service/kafka                         ClusterIP   10.100.xxx.xxx   <none>        9092/TCP   10m
# service/zookeeper                     ClusterIP   10.100.xxx.xxx   <none>        2181/TCP   10m
#
# NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/approval-processing-service 2/2     2            2           10m
# deployment.apps/approval-request-service    2/2     2            2           10m
# deployment.apps/employee-service            2/2     2            2           10m
# deployment.apps/notification-service        2/2     2            2           10m
# deployment.apps/kafka                       1/1     1            1           10m
# deployment.apps/zookeeper                   1/1     1            1           10m
```

### 5-2. Git이 진실인지 확인

```bash
# Git의 values-dev.yaml 확인
cat helm-chart/values-dev.yaml | grep "tag:"

# 예상 출력:
#       tag: a1b2c3d

# 클러스터의 이미지 태그 확인
kubectl get deployment employee-service -n erp-dev -o jsonpath='{.spec.template.spec.containers[0].image}'

# 예상 출력:
# 806332783810.dkr.ecr.ap-northeast-2.amazonaws.com/erp/employee-service:a1b2c3d
```

**확인 사항:**
-  Git의 tag와 클러스터의 tag가 일치
-  Git이 진실 (Source of Truth)

### 5-3. 최종 체크리스트

**Helm:**
- [ ] helm list 성공
- [ ] helm history 확인
- [ ] helm get values 확인

**Kubernetes:**
- [ ] 모든 Pod Running
- [ ] 모든 Service ClusterIP
- [ ] 4개 TargetGroupBinding 존재
- [ ] 4개 HPA 존재
- [ ] 이미지 태그가 Git 커밋 해시

**AWS:**
- [ ] NLB Target 모두 healthy
- [ ] API Gateway 테스트 성공
- [ ] CodePipeline 자동 트리거 성공

**Git:**
- [ ] values-dev.yaml 이미지 태그 업데이트됨
- [ ] Git과 클러스터 일치 (Source of Truth)

**롤백:**
- [ ] helm rollback 성공
- [ ] Pod 재시작 확인
- [ ] API Gateway 테스트 성공

---

##  재구축 완료!

### 개선 사항 요약

**Before (문제):**
-  4개 CodePipeline (관리 복잡)
-  kubectl set image (Manifests 반영 안 됨)
-  Plain YAML (환경 분리 불가)
-  Secret 평문 (보안 취약)
-  NLB 중복 (비용 낭비)
-  Git이 진실 아님

**After (해결):**
-  1개 CodePipeline (단일 관리)
-  helm upgrade (Manifests 자동 반영)
-  Helm Chart (환경 분리 가능)
-  Secrets Manager (보안 강화)
-  NLB 1개 (비용 절감)
-  Git이 진실 (Source of Truth)

### CodePipeline 강점 극대화

-  AWS Secrets Manager 통합
-  Parameter Store 활용
-  ECR 이미지 스캔 자동화
-  CloudWatch Logs 중앙 집중
-  변경 감지 로직 (Git diff)
-  Helm 배포 (롤백 가능)

---

##  다음 작업 (선택)

### 1. 운영계 환경 추가

```bash
# values-prod.yaml 생성
cp helm-chart/values-dev.yaml helm-chart/values-prod.yaml

# 운영계 설정 수정
# - replicaCount: 5
# - resources.limits.memory: 2Gi
# - targetGroupArn: 운영계 ARN

# 운영계 배포
helm upgrade --install erp-microservices helm-chart/ \
  -f helm-chart/values-prod.yaml \
  -n erp-prod \
  --create-namespace
```

### 2. Lambda 하이브리드 구조 (비용 21% 절감)

```bash
# Employee Service를 Lambda로 전환
# 상세: infrastructure/README.md - 하이브리드 구조 미구현
```

### 3. 모니터링 추가

```bash
# Prometheus + Grafana 설치
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

---

##  학습 포인트

### 1. Helm의 가치

- 환경 분리 (values-dev.yaml, values-prod.yaml)
- 템플릿 재사용 (중복 제거)
- 버전 관리 (helm history)
- 롤백 (helm rollback)

### 2. CodePipeline vs GitOps

| 항목 | CodePipeline (Push) | ArgoCD (Pull) |
|------|---------------------|---------------|
| 배포 방식 | buildspec.yml에서 helm upgrade | ArgoCD가 Git 감시 후 자동 sync |
| Drift Detection | 없음 | 있음 (Git과 클러스터 비교) |
| AWS 통합 | 강함 (Secrets Manager, ECR 스캔) | 약함 (별도 설정 필요) |
| 학습 곡선 | 낮음 (AWS 네이티브) | 높음 (GitOps 개념) |

### 3. Git as Source of Truth

- Git의 values-dev.yaml이 진실
- buildspec.yml이 values 업데이트 후 helm upgrade
- 클러스터는 Git을 따름

---

**"재구축 완료! 이제 포트폴리오에 자신 있게 올릴 수 있습니다!"**
