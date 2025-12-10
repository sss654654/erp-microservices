# ERP 프론트엔드

**프레임워크**: React 18  
**빌드 도구**: Vite  
**언어**: JavaScript (ES6+)  
**배포**: AWS S3 + CloudFront  
**최종 업데이트**: 2025-12-10

---

## 📋 프로젝트 개요

ERP 전자결재 시스템의 React 기반 프론트엔드 애플리케이션입니다.

### 주요 기능

- ✅ 직원 관리 (목록, 생성, 수정, 삭제)
- ✅ 결재 요청 생성
- ✅ 결재 대기 목록 조회
- ✅ 결재 승인/반려
- ✅ 실시간 알림 (WebSocket)
- ✅ 전체 결재 내역 조회

---

## 🏗️ 프로젝트 구조

```
frontend/
├── public/                 # 정적 파일
├── src/
│   ├── components/         # React 컴포넌트
│   │   ├── EmployeeManagement.jsx      # 직원 관리
│   │   ├── CreateApproval.jsx           # 결재 요청
│   │   ├── ApprovalQueue.jsx            # 대기 목록
│   │   ├── AllApprovals.jsx             # 전체 결재
│   │   └── Notifications.jsx            # 실시간 알림
│   ├── services/           # API 서비스
│   │   ├── employeeService.js           # 직원 API
│   │   ├── approvalService.js           # 결재 API
│   │   ├── processingService.js         # 처리 API
│   │   └── notificationService.js       # WebSocket
│   ├── config/             # 설정
│   │   └── api.js                       # API 엔드포인트
│   ├── App.jsx             # 메인 컴포넌트
│   ├── App.css             # 스타일
│   └── main.jsx            # 진입점
├── package.json
├── vite.config.js
└── .env.production         # 프로덕션 환경 변수
```

---

## 🚀 빠른 시작

### 사전 요구사항

- Node.js 18+
- npm 9+

### 1. 의존성 설치

```bash
cd frontend
npm install
```

### 2. 로컬 개발 서버 실행

```bash
npm run dev
```

**접속**: http://localhost:5173

### 3. 프로덕션 빌드

```bash
npm run build
```

**출력**: `dist/` 폴더

---

## 🔧 환경 설정

### .env (로컬 개발)

```env
VITE_API_BASE_URL=http://localhost
VITE_WS_BASE_URL=http://localhost:8084
```

### .env.production (프로덕션)

```env
VITE_API_BASE_URL=https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev
VITE_WS_BASE_URL=http://a1f6404ce73204456ab80c9b7067c1b7-31ca2443dda9c9fd.elb.ap-northeast-2.amazonaws.com:8084
```

---

## 📦 주요 의존성

```json
{
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "@stomp/stompjs": "^7.0.0",
    "sockjs-client": "^1.6.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "vite": "^5.4.21"
  }
}
```

---

## 🎨 컴포넌트 설명

### 1. EmployeeManagement

**역할**: 직원 목록 조회 및 관리

**기능**:
- 전체 직원 목록 표시
- 직원 생성 폼
- 직원 수정
- 직원 삭제

**API 호출**:
```javascript
import { employeeService } from '../services/employeeService';

// 전체 조회
const employees = await employeeService.getAll();

// 생성
await employeeService.create({ name, department, position });

// 수정
await employeeService.update(id, { name, department, position });

// 삭제
await employeeService.delete(id);
```

### 2. CreateApproval

**역할**: 결재 요청 생성

**기능**:
- 결재 제목, 내용 입력
- 결재 단계 추가 (최대 5단계)
- 각 단계별 결재자 선택

**API 호출**:
```javascript
import { approvalService } from '../services/approvalService';

await approvalService.create({
  requesterId: 4,
  title: "연차 신청",
  content: "12월 15일 연차 사용 신청합니다.",
  steps: [
    { step: 1, approverId: 5 },
    { step: 2, approverId: 6 }
  ]
});
```

### 3. ApprovalQueue

**역할**: 결재자별 대기 목록 조회

**기능**:
- 결재자 ID 입력
- 대기 중인 결재 목록 표시
- 승인/반려 버튼

**API 호출**:
```javascript
import { processingService } from '../services/processingService';

// 대기 목록 조회
const queue = await processingService.getQueue(approverId);

// 승인
await processingService.approve(approverId, requestId);

// 반려
await processingService.reject(approverId, requestId);
```

### 4. AllApprovals

**역할**: 전체 결재 내역 조회

**기능**:
- 모든 결재 요청 표시
- 결재 상태 표시 (진행 중, 승인, 반려)
- 결재 단계별 상태 표시

**API 호출**:
```javascript
import { approvalService } from '../services/approvalService';

const approvals = await approvalService.getAll();
```

### 5. Notifications

**역할**: 실시간 알림 수신

**기능**:
- WebSocket 연결
- 알림 수신 및 표시
- 최근 10개 알림 유지

**WebSocket 연결**:
```javascript
import { notificationService } from '../services/notificationService';

notificationService.connect((notification) => {
  console.log('Received:', notification);
  // 알림 처리
});
```

---

## 🌐 API 서비스

### employeeService.js

```javascript
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL;

export const employeeService = {
  getAll: () => fetch(`${API_BASE_URL}/api/employees`).then(res => res.json()),
  getById: (id) => fetch(`${API_BASE_URL}/api/employees/${id}`).then(res => res.json()),
  create: (data) => fetch(`${API_BASE_URL}/api/employees`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).then(res => res.json()),
  update: (id, data) => fetch(`${API_BASE_URL}/api/employees/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).then(res => res.json()),
  delete: (id) => fetch(`${API_BASE_URL}/api/employees/${id}`, {
    method: 'DELETE'
  })
};
```

### notificationService.js

```javascript
import { Client } from '@stomp/stompjs';
import SockJS from 'sockjs-client';

const WS_BASE_URL = import.meta.env.VITE_WS_BASE_URL;

export const notificationService = {
  connect: (onMessageReceived) => {
    const socket = new SockJS(`${WS_BASE_URL}/ws/notifications`);
    const stompClient = new Client({
      webSocketFactory: () => socket,
      onConnect: () => {
        console.log('WebSocket Connected');
        stompClient.subscribe('/topic/notifications', (message) => {
          const notification = JSON.parse(message.body);
          onMessageReceived(notification);
        });
      },
      onStompError: (frame) => {
        console.error('STOMP error:', frame);
      },
    });
    stompClient.activate();
  }
};
```

---

## 🚢 배포

### S3 + CloudFront 배포

```bash
# 1. 빌드
npm run build

# 2. S3 업로드
aws s3 sync dist/ s3://erp-dev-frontend-dev --delete --region ap-northeast-2

# 3. CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E3HPT0O3YKLR5N \
  --paths "/*" \
  --region ap-northeast-2
```

### 배포 URL

- **HTTPS (CloudFront)**: https://d95pjcr73gr6g.cloudfront.net
- **HTTP (S3)**: http://erp-dev-frontend-dev.s3-website.ap-northeast-2.amazonaws.com

**주의**: WebSocket 연결은 HTTP 페이지에서만 가능 (ws:// 프로토콜)

---

## 🧪 테스트

### 수동 테스트

1. **직원 관리**
   - 직원 생성 → 목록에 표시 확인
   - 직원 수정 → 변경 사항 반영 확인
   - 직원 삭제 → 목록에서 제거 확인

2. **결재 요청**
   - 결재 생성 → requestId 반환 확인
   - 대기 목록 조회 → 결재 표시 확인

3. **결재 처리**
   - 승인 → 다음 단계로 전달 확인
   - 반려 → 최종 상태 변경 확인

4. **실시간 알림**
   - WebSocket 연결 확인 (Console 로그)
   - 결재 승인/반려 시 알림 수신 확인

---

## 🐛 트러블슈팅

### WebSocket 연결 실패

**문제**: `WebSocket connection failed`

**해결**:
1. HTTP 페이지로 접속 (http://erp-dev-frontend-dev.s3-website...)
2. HTTPS 페이지에서는 ws:// 연결 불가 (브라우저 보안 정책)

### CORS 에러

**문제**: `Access-Control-Allow-Origin` 에러

**해결**:
- API Gateway CORS 설정 확인
- AllowOrigins: `*` 또는 특정 도메인

### API 호출 실패

**문제**: `Failed to fetch`

**해결**:
```bash
# API Gateway URL 확인
echo $VITE_API_BASE_URL

# 네트워크 탭에서 요청 URL 확인
# 올바른 형식: https://mqi4qaw3bb.../dev/api/employees
```

---

## 📚 참고 자료

- [React Documentation](https://react.dev/)
- [Vite Documentation](https://vitejs.dev/)
- [STOMP.js](https://stomp-js.github.io/stomp-websocket/)
- [SockJS](https://github.com/sockjs/sockjs-client)

---

## 📄 라이선스

MIT License
