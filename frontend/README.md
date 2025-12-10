# Frontend

React 기반 ERP 시스템 프론트엔드입니다.

## 기술 스택

- React 18
- Vite (빌드 도구)
- Axios (HTTP 클라이언트)
- @stomp/stompjs (WebSocket)

## 구조

```
frontend/
├── src/
│   ├── components/          # React 컴포넌트
│   │   ├── EmployeeManagement.jsx
│   │   ├── CreateApproval.jsx
│   │   ├── ApprovalQueue.jsx
│   │   ├── AllApprovals.jsx
│   │   └── Notifications.jsx
│   ├── services/            # API 호출 로직
│   │   ├── employeeService.js
│   │   ├── approvalService.js
│   │   ├── processingService.js
│   │   └── notificationService.js
│   ├── config/              # 설정
│   │   └── api.js
│   ├── App.jsx              # 메인 앱
│   └── main.jsx             # 엔트리 포인트
├── public/                  # 정적 파일
├── .env                     # 로컬 환경 변수
├── .env.production          # 프로덕션 환경 변수
└── vite.config.js           # Vite 설정
```

## 주요 기능

### 직원 관리
- 직원 목록 조회
- 직원 생성/수정/삭제

### 결재 관리
- 결재 신청 (다단계 결재자 선택)
- 내 결재 대기 목록 조회
- 결재 승인/반려
- 전체 결재 목록 조회

### 실시간 알림
- WebSocket (STOMP) 연결
- 결재 승인/반려 시 실시간 알림 수신

## 로컬 실행

```bash
# 의존성 설치
npm install

# 개발 서버 실행 (http://localhost:5173)
npm run dev

# 프로덕션 빌드
npm run build
```

## AWS 배포

```bash
# 빌드
npm run build

# S3 업로드
aws s3 sync dist/ s3://erp-dev-frontend-dev/ --delete

# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E3HPT0O3YKLR5N \
  --paths "/*"
```

## 환경 변수

**.env (로컬)**:
```
VITE_API_BASE_URL=http://localhost:8080
```

**.env.production (AWS)**:
```
VITE_API_BASE_URL=https://mqi4qaw3bb.execute-api.ap-northeast-2.amazonaws.com/dev
```

## API 통신

모든 API 호출은 `src/config/api.js`에서 설정된 Base URL을 사용합니다.

```javascript
// src/config/api.js
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';
```

## WebSocket 연결

```javascript
// src/services/notificationService.js
const client = new Client({
  brokerURL: 'ws://localhost:8084/ws/notifications',
  onConnect: () => {
    client.subscribe(`/topic/notifications/${employeeId}`, callback);
  }
});
```

## 배포 URL

- **CloudFront**: https://d95pjcr73gr6g.cloudfront.net
- **S3 Bucket**: erp-dev-frontend-dev
