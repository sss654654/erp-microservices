# Cognito + 프론트엔드 통합 가이드

## 📋 구현 완료 내용

### 1. Cognito 인프라 (Terraform)
- **위치**: `infrastructure/terraform/dev/erp-dev-Cognito/`
- **전략**: 통합 전략 (User Pool + App Client 함께 관리)
- **속성**:
  - email (로그인 ID)
  - name (이름)
  - custom:position (직급: STAFF/MANAGER)
  - custom:department (부서: DEVELOPMENT/SALES/HR/FINANCE)
  - custom:employeeId (직원 ID, 자동 할당)

### 2. 프론트엔드 기능
- ✅ **인증**: 로그인/회원가입/로그아웃
- ✅ **출석 체크**: 30일 퀘스트 진행률 표시, 자동 연차 지급
- ✅ **퀘스트 시스템** (사원):
  - 가능한 퀘스트 목록
  - 퀘스트 수락/완료/보상 받기
  - 내 퀘스트 상태 관리
- ✅ **퀘스트 관리** (부장):
  - 커스텀 퀘스트 생성
  - 직원 완료 보고 승인/반려
  - 퀘스트 삭제
- ✅ **직급별 메뉴 분기**: position 기반 UI 분리
- ✅ **동적 UI**: Framer Motion 애니메이션, 스무스 전환

---

## 🚀 배포 순서

### 1단계: Cognito 배포

```bash
cd infrastructure/terraform/dev/erp-dev-Cognito
terraform init
terraform plan
terraform apply -auto-approve
```

**출력값 확인**:
```bash
terraform output user_pool_id
terraform output user_pool_client_id
```

### 2단계: 프론트엔드 환경 변수 설정

`.env` 파일 업데이트:
```bash
VITE_COGNITO_USER_POOL_ID=ap-northeast-2_xxxxxxxxx
VITE_COGNITO_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 3단계: 프론트엔드 패키지 설치

```bash
cd frontend
npm install
```

새로 추가된 패키지:
- `amazon-cognito-identity-js`: Cognito 인증
- `framer-motion`: 애니메이션
- `react-router-dom`: 라우팅

### 4단계: 로컬 테스트

```bash
npm run dev
```

브라우저에서 `http://localhost:5173` 접속

### 5단계: 프로덕션 빌드 & 배포

```bash
npm run build
aws s3 sync dist/ s3://erp-dev-frontend-bucket --delete
aws cloudfront create-invalidation --distribution-id <DISTRIBUTION_ID> --paths "/*"
```

---

## 🎮 사용 시나리오

### 시나리오 1: 사원 출석 퀘스트

1. **회원가입**:
   - 이메일: `staff@example.com`
   - 비밀번호: `Password123`
   - 이름: `김사원`
   - 직급: `사원`
   - 부서: `개발팀`

2. **로그인** → 대시보드 진입

3. **출석 체크**:
   - "출근하기" 버튼 클릭
   - 진행률 바 업데이트 (예: 1/30 = 3%)
   - 30일 달성 시 연차 1일 자동 지급

4. **퀘스트 수락**:
   - "가능한 퀘스트" 탭
   - 부장이 만든 퀘스트 확인
   - "수락하기" 클릭

5. **오프라인 업무 수행** (예: 커피 끓여오기)

6. **완료 보고**:
   - "내 퀘스트" 탭
   - "완료 보고" 클릭
   - 상태: `승인 대기`

7. **부장 승인 후**:
   - 상태: `승인됨`
   - "보상 받기" 클릭
   - 연차 추가 (예: 0.5일)

### 시나리오 2: 부장 퀘스트 관리

1. **회원가입**:
   - 이메일: `manager@example.com`
   - 비밀번호: `Password123`
   - 이름: `박부장`
   - 직급: `부장`
   - 부서: `개발팀`

2. **로그인** → 대시보드 진입

3. **퀘스트 생성**:
   - "+ 새 퀘스트" 클릭
   - 제목: `커피 끓여오기`
   - 설명: `아메리카노 2잔`
   - 보상: `0.5일`
   - "생성하기" 클릭

4. **직원 완료 보고 확인**:
   - 진행 현황에 `김사원` 표시
   - 상태: `승인 대기`

5. **승인/반려**:
   - "승인" 클릭 → 직원이 보상 받을 수 있음
   - "반려" 클릭 → 사유 입력 → 직원에게 다시 진행 요청

---

## 🎨 화면 구성

### 로그인 화면
- 그라데이션 배경
- 로그인/회원가입 토글
- 이메일 인증 (Cognito 자동)

### 대시보드 (사원)
- **출석 카드**: 진행률 바, 출근 버튼
- **퀘스트 목록**: 가능한 퀘스트 / 내 퀘스트 탭

### 대시보드 (부장)
- **출석 카드**: 동일
- **퀘스트 관리**: 생성 폼, 진행 현황, 승인/반려

### 결재 탭
- 기존 결재 시스템 (변경 없음)

### 관리 탭 (부장 전용)
- 직원 관리
- 팀원 목록
- 연차 조정

---

## 🔧 API 연동

### 출석 API
```javascript
// 출근
POST /api/employees/attendance/check-in/{employeeId}
Response: { attendanceCount, rewardEarned, currentLeaveBalance }

// 진행률 조회
GET /api/employees/attendance/progress/{employeeId}
Response: { attendanceCount, targetCount, progress, nextRewardAt }
```

### 퀘스트 API (사원)
```javascript
// 가능한 퀘스트
GET /api/employees/quests/available?employeeId={id}

// 수락
POST /api/employees/quests/{questId}/accept
Body: { employeeId }

// 완료 보고
POST /api/employees/quests/{questId}/complete
Body: { employeeId }

// 보상 받기
POST /api/employees/quests/{questId}/claim
Body: { employeeId }

// 내 퀘스트
GET /api/employees/quests/my-quests?employeeId={id}
```

### 퀘스트 API (부장)
```javascript
// 생성
POST /api/employees/quests
Body: { title, description, rewardDays, department, createdBy }

// 내가 만든 퀘스트
GET /api/employees/quests/my-created?managerId={id}

// 승인
PUT /api/employees/quests/{questId}/approve
Body: { managerId }

// 반려
PUT /api/employees/quests/{questId}/reject
Body: { managerId, reason }

// 삭제
DELETE /api/employees/quests/{questId}
```

---

## 🐛 트러블슈팅

### 1. Cognito User Pool ID가 없어요
```bash
cd infrastructure/terraform/dev/erp-dev-Cognito
terraform output user_pool_id
```
출력값을 `.env`에 복사

### 2. 로그인 시 "User does not exist" 에러
- 회원가입 후 이메일 인증 필요
- Cognito 콘솔에서 수동 확인 가능

### 3. 퀘스트 API 404 에러
- Employee Service가 실행 중인지 확인
- API Gateway 라우팅 확인

### 4. 애니메이션이 작동하지 않아요
```bash
npm install framer-motion
```

### 5. 빌드 에러: "Cannot find module 'amazon-cognito-identity-js'"
```bash
npm install amazon-cognito-identity-js
```

---

## 📝 TODO

- [ ] Cognito terraform apply 실행
- [ ] User Pool ID, Client ID 확인
- [ ] 프론트엔드 .env 업데이트
- [ ] npm install 실행
- [ ] 로컬 테스트
- [ ] 프로덕션 배포
- [ ] 백엔드 API 테스트
- [ ] 사원/부장 시나리오 테스트

---

## 🎯 핵심 포인트

1. **Cognito 통합 전략**: User Pool + App Client 함께 관리
2. **직급별 분기**: `user.position === 'MANAGER'` 조건부 렌더링
3. **동적 UI**: Framer Motion으로 스무스한 전환
4. **게이미피케이션**: 출석 → 연차 자동 지급, 부장 커스텀 퀘스트
5. **백엔드 API 활용**: 기존 API 그대로 사용, 프론트만 추가

---

**작성일**: 2025-12-11  
**작성자**: Amazon Q
