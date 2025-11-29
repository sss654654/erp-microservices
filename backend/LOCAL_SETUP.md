# ERP 마이크로서비스 로컬 실행 가이드

## 시스템 요구사항

- Docker 20.10+
- Docker Compose 2.0+
- 최소 8GB RAM
- 포트: 3306, 27017, 6380, 8081-8084, 9090-9091

## 서비스 구성

| 서비스 | 포트 | 역할 | 통신 |
|--------|------|------|------|
| MySQL | 3306 | Employee 데이터 저장 | - |
| MongoDB | 27017 | Approval Request 데이터 저장 | - |
| Redis | 6380 | 캐싱 (향후 확장용) | - |
| Employee Service | 8081 | 직원 관리 | REST |
| Approval Request Service | 8082, 9091 | 결재 요청 관리 | REST, gRPC Server |
| Approval Processing Service | 8083, 9090 | 결재 처리 로직 | REST, gRPC Server |
| Notification Service | 8084 | 실시간 알림 | WebSocket |

## 실행 방법

### 1. 전체 서비스 실행

```bash
cd erp-project/backend
docker-compose up --build
```

**빌드 시간**: 약 5-10분 (Maven 의존성 다운로드 포함)

### 2. 서비스 상태 확인

```bash
docker-compose ps
```

**정상 실행 시**:
```
NAME                          STATUS
erp-mysql                     Up (healthy)
erp-mongodb                   Up (healthy)
erp-redis                     Up
employee-service              Up
approval-request-service      Up
approval-processing-service   Up
notification-service          Up
```

### 3. 로그 확인

```bash
# 전체 로그
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f employee-service
docker-compose logs -f approval-request-service
```

### 4. 서비스 중지

```bash
docker-compose down
```

**데이터 삭제 포함**:
```bash
docker-compose down -v
```

## 테스트 시나리오

### 시나리오 1: 결재 승인 완료 (2단계)

#### 1-1. 직원 3명 생성

**요청자 (ID: 1)**:
```bash
curl -X POST http://localhost:8081/employees \
  -H "Content-Type: application/json" \
  -d '{
    "name": "김철수",
    "department": "개발팀",
    "position": "사원"
  }'
```

**결재자 1 (ID: 2)**:
```bash
curl -X POST http://localhost:8081/employees \
  -H "Content-Type: application/json" \
  -d '{
    "name": "이영희",
    "department": "개발팀",
    "position": "팀장"
  }'
```

**결재자 2 (ID: 3)**:
```bash
curl -X POST http://localhost:8081/employees \
  -H "Content-Type: application/json" \
  -d '{
    "name": "박민수",
    "department": "경영지원팀",
    "position": "부장"
  }'
```

#### 1-2. 2단계 결재 요청 생성

```bash
curl -X POST http://localhost:8082/approvals \
  -H "Content-Type: application/json" \
  -d '{
    "requesterId": 1,
    "title": "휴가 신청",
    "content": "2025-12-01 연차 사용 신청합니다",
    "steps": [
      {"step": 1, "approverId": 2},
      {"step": 2, "approverId": 3}
    ]
  }'
```

**응답**:
```json
{"requestId": 1}
```

**처리 흐름**:
1. Employee Service에서 직원 검증 (REST)
2. MongoDB에 저장 (finalStatus: "in_progress")
3. gRPC로 Processing Service에 RequestApproval 호출
4. Processing Service가 결재자 2의 대기 목록에 추가

#### 1-3. 결재자 1의 대기 목록 조회

```bash
curl http://localhost:8083/process/2
```

**응답**:
```json
[
  {
    "requestId": 1,
    "requesterId": 1,
    "title": "휴가 신청",
    "content": "2025-12-01 연차 사용 신청합니다",
    "steps": [
      {"step": 1, "approverId": 2, "status": "pending"},
      {"step": 2, "approverId": 3, "status": "pending"}
    ]
  }
]
```

#### 1-4. 결재자 1 승인

```bash
curl -X POST http://localhost:8083/process/2/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "approved"}'
```

**처리 흐름**:
1. Processing Service가 대기 목록에서 제거
2. gRPC로 Request Service에 ReturnApprovalResult 호출
3. Request Service가 MongoDB 업데이트 (step 1: "approved")
4. 다음 pending 단계가 있으므로 RequestApproval 재호출
5. Processing Service가 결재자 3의 대기 목록에 추가

#### 1-5. 결재자 2의 대기 목록 조회

```bash
curl http://localhost:8083/process/3
```

**응답**:
```json
[
  {
    "requestId": 1,
    "steps": [
      {"step": 1, "approverId": 2, "status": "approved"},
      {"step": 2, "approverId": 3, "status": "pending"}
    ]
  }
]
```

#### 1-6. 결재자 2 승인

```bash
curl -X POST http://localhost:8083/process/3/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "approved"}'
```

**처리 흐름**:
1. Processing Service가 대기 목록에서 제거
2. gRPC로 Request Service에 ReturnApprovalResult 호출
3. Request Service가 MongoDB 업데이트 (step 2: "approved")
4. 모든 단계 완료 → finalStatus: "approved"
5. Notification Service 호출 (요청자에게 승인 완료 알림)

#### 1-7. 최종 결과 확인

```bash
curl http://localhost:8082/approvals/1
```

**응답**:
```json
{
  "requestId": 1,
  "requesterId": 1,
  "title": "휴가 신청",
  "steps": [
    {
      "step": 1,
      "approverId": 2,
      "status": "approved",
      "updatedAt": "2025-11-28T22:30:00"
    },
    {
      "step": 2,
      "approverId": 3,
      "status": "approved",
      "updatedAt": "2025-11-28T22:35:00"
    }
  ],
  "finalStatus": "approved",
  "createdAt": "2025-11-28T22:25:00",
  "updatedAt": "2025-11-28T22:35:00"
}
```

---

### 시나리오 2: 결재 반려

#### 2-1. 결재 요청 생성

```bash
curl -X POST http://localhost:8082/approvals \
  -H "Content-Type: application/json" \
  -d '{
    "requesterId": 1,
    "title": "출장 신청",
    "content": "서울 본사 출장 신청",
    "steps": [
      {"step": 1, "approverId": 2}
    ]
  }'
```

#### 2-2. 결재자 반려

```bash
curl -X POST http://localhost:8083/process/2/2 \
  -H "Content-Type: application/json" \
  -d '{"status": "rejected"}'
```

**처리 흐름**:
1. Processing Service가 대기 목록에서 제거
2. gRPC로 Request Service에 ReturnApprovalResult 호출
3. Request Service가 MongoDB 업데이트 (step 1: "rejected")
4. finalStatus: "rejected" (즉시 종료)
5. Notification Service 호출 (요청자에게 반려 알림)

#### 2-3. 결과 확인

```bash
curl http://localhost:8082/approvals/2
```

**응답**:
```json
{
  "requestId": 2,
  "finalStatus": "rejected",
  "steps": [
    {
      "step": 1,
      "approverId": 2,
      "status": "rejected",
      "updatedAt": "2025-11-28T22:40:00"
    }
  ]
}
```

---

### 시나리오 3: WebSocket 실시간 알림

#### 3-1. WebSocket 연결 (JavaScript)

```html
<!DOCTYPE html>
<html>
<head>
    <script src="https://cdn.jsdelivr.net/npm/sockjs-client@1/dist/sockjs.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@stomp/stompjs@7/bundles/stomp.umd.min.js"></script>
</head>
<body>
    <h1>ERP 알림</h1>
    <div id="notifications"></div>

    <script>
        const socket = new SockJS('http://localhost:8084/ws/notifications');
        const stompClient = Stomp.over(socket);

        stompClient.connect({}, function(frame) {
            console.log('Connected: ' + frame);
            
            stompClient.subscribe('/topic/notifications', function(message) {
                const notification = JSON.parse(message.body);
                showNotification(notification);
            });
        });

        function showNotification(notification) {
            const div = document.getElementById('notifications');
            div.innerHTML += `<p>${notification.message} (${notification.status})</p>`;
        }
    </script>
</body>
</html>
```

#### 3-2. 알림 발송 테스트

```bash
curl -X POST http://localhost:8084/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "approvalId": "test123",
    "status": "APPROVED",
    "message": "결재가 승인되었습니다"
  }'
```

**결과**: 브라우저에서 실시간으로 알림 수신

---

## 트러블슈팅

### 1. 포트 충돌

**증상**: `port is already allocated`

**해결**:
```bash
# 포트 사용 중인 프로세스 확인
lsof -i :8081
lsof -i :3306

# 프로세스 종료
kill -9 <PID>
```

### 2. MySQL 연결 실패

**증상**: `Communications link failure`

**해결**:
```bash
# MySQL 컨테이너 로그 확인
docker-compose logs mysql

# healthcheck 대기
docker-compose ps
```

### 3. gRPC 연결 실패

**증상**: `UNAVAILABLE: io exception`

**해결**:
```bash
# Processing Service가 먼저 시작되었는지 확인
docker-compose logs approval-processing-service

# 재시작
docker-compose restart approval-request-service
```

### 4. MongoDB 연결 실패

**증상**: `MongoSocketOpenException`

**해결**:
```bash
# MongoDB 컨테이너 상태 확인
docker-compose ps mongodb

# 재시작
docker-compose restart mongodb
```

### 5. 빌드 실패

**증상**: `Failed to execute goal`

**해결**:
```bash
# Maven 캐시 삭제
docker-compose down
docker system prune -a

# 재빌드
docker-compose up --build
```

---

## 데이터베이스 직접 접근

### MySQL

```bash
docker exec -it erp-mysql mysql -uroot -proot erp

# 직원 목록 조회
SELECT * FROM employees;
```

### MongoDB

```bash
docker exec -it erp-mongodb mongosh erp

# 결재 요청 목록 조회
db.approval_requests.find().pretty()
```

---

## Postman Collection

`ERP_Postman_Collection.json` 파일을 Postman에 import하여 사용하세요.

**포함된 API**:
- Employee Service: 6개 API
- Approval Request Service: 3개 API
- Approval Processing Service: 2개 API
- Notification Service: 2개 API

---

## 다음 단계

로컬 환경에서 검증 완료 후:

1. **SOLID Cloud 배포** (무료)
   - Docker Compose 파일 그대로 배포
   - 외부 접근 가능한 URL 확인
   - 프론트엔드 연동 테스트

2. **AWS 배포** (2단계)
   - Terraform으로 인프라 구축
   - EKS 클러스터 배포
   - CI/CD 파이프라인 구축

3. **Kafka 통합** (3단계)
   - gRPC 동기 → Kafka 비동기 전환
   - 이벤트 기반 아키텍처
