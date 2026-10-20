# 하루한번 — 백엔드 추가 API 명세

> 대상: 백엔드 개발자
> 프론트엔드는 아래 API를 **이미 호출하도록 구현되어 있습니다.** 지금은 샘플 데이터로 동작하며, 서버에 이 명세대로 엔드포인트가 생기면 스위치 하나로 실제 데이터로 바뀝니다.

## 연결 방법 (프론트엔드)

```bash
# 실제 API 사용
flutter run --dart-define=HARU_PENDING_DUMMY=false
```

또는 [lib/data/pending/pending_api.dart](lib/data/pending/pending_api.dart)의 `kPendingUseDummy` 기본값을 `false`로 바꿉니다.
**스토어 배포 전 반드시 `false`여야 합니다** — 샘플 데이터(연속 답변 12일, 답장 달력 등)는 실제 사용자 데이터가 아닙니다.

| 파일 | 역할 |
|---|---|
| [pending_api.dart](lib/data/pending/pending_api.dart) | 인터페이스 + 샘플/실제 전환 스위치 |
| [pending_http.dart](lib/data/pending/pending_http.dart) | 실제 HTTP 호출 (이 문서의 URL 그대로) |
| [pending_models.dart](lib/data/pending/pending_models.dart) | 응답 JSON 파서 (이 문서의 필드명 그대로) |
| [pending_dummy.dart](lib/data/pending/pending_dummy.dart) | 샘플 데이터 |

## 공통 규칙

- 인증: 기존과 같이 `Authorization: Bearer {accessToken}`. 401이면 앱이 `/api/auth/refresh` 후 1회 재시도합니다.
- 날짜: `YYYY-MM-DD` (가족 기준 로컬 날짜). 일시: ISO-8601 (`2026-09-25T08:10:00+09:00`).
- "나"는 토큰의 사용자, "가족"은 그 사용자가 속한 가족입니다.
- 에러는 기존 형식 `{ "message": "...", "code": "..." }`을 유지해 주세요.

---

## 신규 엔드포인트

### P1. 연속 답변 스트릭

`GET /api/families/me/streak`

홈 상단 "♥ 12일" 칩, 연속 답변 카드, 연속 답변 시트("최고 기록 12일")에 쓰입니다.

```json
{
  "currentStreak": 12,
  "bestStreak": 12,
  "answeredToday": false,
  "week": [
    { "date": "2026-09-21", "answered": true },
    { "date": "2026-09-22", "answered": true },
    { "date": "2026-09-23", "answered": true },
    { "date": "2026-09-24", "answered": true },
    { "date": "2026-09-25", "answered": false },
    { "date": "2026-09-26", "answered": false },
    { "date": "2026-09-27", "answered": false }
  ]
}
```

| 필드 | 타입 | 설명 |
|---|---|---|
| `currentStreak` | int | **내가** 연속으로 답한 일수. 오늘 답했으면 오늘 포함, 아직이면 어제까지 |
| `bestStreak` | int | 지금까지 가장 길었던 연속 답변 일수. 없으면 "최고 기록" 문구를 숨깁니다 |
| `answeredToday` | bool | 오늘 질문에 내가 답했는지 |
| `week` | array(7) | **이번 주 월요일 → 일요일**. 미래 날짜는 `false` |

---

### P2. 날짜별 답변 현황

`GET /api/families/me/daily-question/answer-status?year=2026&month=9`

가장 많이 쓰이는 API입니다.
- 홈 주간 날짜 줄: 내가 답한 날 아래 점
- 기록 > 날짜별: 구성원 점 + "3/4 답장"
- 기록 > 리포트: "이번 달 답장 N개", "모두 함께 답한 날 N일", 월간 답장 달력
- 가족 탭 "이번 달 참여": 구성원별 "18/21일" 막대

```json
{
  "days": [
    { "date": "2026-09-25", "answeredUserIds": [11, 12] },
    { "date": "2026-09-24", "answeredUserIds": [11, 12, 13, 14] }
  ]
}
```

| 필드 | 타입 | 설명 |
|---|---|---|
| `days[].date` | string | 질문이 배포된 날짜. 질문이 없는 날은 생략 가능 |
| `days[].answeredUserIds` | int[] | 그 날 질문에 답한 구성원 `userId` 목록 |

---

### P3 · P4 · P5. 주간/월간 리포트, 구성원별 참여율 — 이제 필요 없음

새 디자인의 리포트와 참여율은 **P2(날짜별 답변 현황)와 기존 일지 달력 API로 앱이 직접 계산**합니다. 아직 만들지 않았다면 만들지 않아도 됩니다. (앱 코드에는 인터페이스가 남아 있지만 화면에서 호출하지 않습니다.)

---

### P6. 알림 목록

`GET /api/me/notifications?page=0&size=30`
`POST /api/me/notifications/read-all` → 204

홈 상단 🔔 (안 읽은 알림이 있으면 주황 점), 알림 화면.
알림 카드는 **제목 한 줄 + 미리보기 한 줄 + 시간**으로 보입니다.

```json
{
  "items": [
    {
      "id": 101,
      "type": "ANSWER_POSTED",
      "message": "엄마가 답장을 남겼어요",
      "preview": "어제 다 같이 저녁 차려준 거! 설거지까지…",
      "actorUserId": 12,
      "createdAt": "2026-09-25T08:10:00+09:00",
      "read": false,
      "target": { "date": "2026-09-25" }
    },
    {
      "id": 96,
      "type": "ALBUM_PHOTOS_ADDED",
      "message": "아빠가 사진 7장을 올렸어요",
      "preview": "추석",
      "actorUserId": 11,
      "createdAt": "2026-09-20T19:00:00+09:00",
      "read": true,
      "target": { "albumId": 4 }
    }
  ],
  "hasMore": false,
  "unreadCount": 3
}
```

| 필드 | 타입 | 설명 |
|---|---|---|
| `message` | string | 제목. 서버가 완성 문장으로 (조사 처리 포함) |
| `preview` | string \| null | 두 번째 줄. 질문 내용, 답장·일지 앞부분, 앨범 이름 등 |
| `actorUserId` | int \| null | 알림을 만든 구성원. 아이콘 배경을 그 사람 색으로 칠합니다 |

| `type` | 눌렀을 때 이동 | `target` |
|---|---|---|
| `QUESTION_ARRIVED` | 홈 | `date` |
| `ANSWER_POSTED` | 그 날의 가족 답장 | `date` |
| `TEMPERATURE_CHANGED` | 가족 탭 (온도 게이지) | — |
| `DIARY_POSTED` | 일지 탭 | `date` |
| `ALBUM_PHOTOS_ADDED` | 앨범 상세 (없으면 앨범 탭) | `albumId` |

기존 FCM 푸시와 **같은 이벤트를 알림 목록에도 저장**하면 됩니다. 알림을 하나 누르거나 "모두 읽음"을 누르면 앱이 `read-all`을 호출합니다. 알림 삭제는 P14.

---

### P7. Apple 로그인

`POST /api/auth/apple`

```json
{ "identityToken": "eyJ...", "authorizationCode": "c1a...", "restoreDeletedAccount": false }
```

응답은 **기존 `/api/auth/kakao`와 같은 `AuthResult`** 입니다.

- 서버: `identityToken`을 Apple 공개키로 검증하고 `sub`로 사용자를 식별합니다.
- 앱: iOS에만 버튼이 보입니다. 현재는 누르면 "Apple 로그인은 준비 중이에요" 안내가 뜹니다.
- 앱 쪽 남은 작업: `sign_in_with_apple` 패키지 추가, Xcode에서 **Sign in with Apple** capability 추가, [pending_http.dart](lib/data/pending/pending_http.dart)의 `loginWithApple` 구현.
- 참고: 카카오 로그인을 제공하는 iOS 앱은 App Store 심사 가이드라인 4.8에 따라 Apple 로그인을 함께 제공해야 합니다.

---

### P8. Google 로그인

`POST /api/auth/google`

```json
{ "idToken": "eyJ...", "restoreDeletedAccount": false }
```

응답은 **기존 `AuthResult`** 입니다. 서버는 `idToken`을 Google 공개키로 검증하고 `sub`로 사용자를 식별합니다.
앱 쪽 남은 작업: `google_sign_in` 패키지, iOS/Android OAuth 클라이언트 ID 등록, [pending_http.dart](lib/data/pending/pending_http.dart)의 `loginWithGoogle` 구현. 지금은 버튼을 누르면 "Google 로그인은 준비 중이에요"가 뜹니다.

---

### P9. 가족 나가기

`DELETE /api/families/me/members/me` → 204

가족 탭 > 가족 나가기. 성공하면 앱은 가족 선택 화면으로 이동합니다. 이후 `/api/auth/me`의 `familyId`는 null이어야 합니다.
가족을 만든 사람이 나갈 때의 처리(다른 사람에게 넘기기 / 막기)는 정해 주세요. 막는다면 `{ "code": "CREATOR_CANNOT_LEAVE" }`처럼 내려주시면 문구를 맞추겠습니다.

---

### P10. 구성원 내보내기

`DELETE /api/families/me/members/{userId}` → 204

가족 탭 > 구성원 관리. **가족을 만든 사람만** 가능합니다 (아니면 403). 내보낸 사람의 답장은 그대로 남습니다.

---

### P11. 콕 찌르기

`POST /api/families/me/daily-questions/{dailyQuestionId}/pokes`

```json
{ "targetUserId": 13 }
```
→ 204

가족 답장 화면에서 아직 답하지 않은 구성원에게 보냅니다 (오늘 질문만). 서버는 대상에게 FCM 푸시를 보내 주세요. 예: "엄마가 콕 찔렀어요. 오늘의 질문에 답장해 볼까요?"
같은 사람에게 하루 한 번만 허용하는 등의 제한이 있다면 409로 알려 주세요.

---

### P12. 문의하기

`POST /api/inquiries`

```json
{ "category": "QUESTION_ANSWER", "content": "불편했던 점..." }
```
→ 204

`category`: `QUESTION_ANSWER` · `NOTIFICATION` · `ACCOUNT` · `ETC`. `content`는 최대 1000자. 답변은 가입한 이메일로 보낸다고 안내하고 있습니다.

---

### P13. 알림 설정

`GET /api/me/notification-settings`
`PUT /api/me/notification-settings` (같은 형식으로 보내고, 저장된 값을 응답)

```json
{
  "questionArrived": true,
  "answerPosted": true,
  "temperatureChanged": true,
  "diaryAlbum": true,
  "dndEnabled": false,
  "dndStart": "22:00",
  "dndEnd": "07:00"
}
```

가족 탭 > 알림 받기 (4가지) + 방해 금지 시간. **푸시를 보낼 때 서버가 이 설정을 확인**해야 합니다.
- 꺼진 종류의 푸시는 보내지 않습니다 (알림 목록 P6에는 저장).
- `dnd*`는 한국 시간 기준 "HH:mm". `dndStart`가 `dndEnd`보다 늦으면 자정을 넘기는 구간입니다 (22:00–07:00).
- 4가지가 모두 꺼지면 앱이 기기 토큰 등록도 해제합니다.

---

### P14. 알림 지우기

`DELETE /api/me/notifications/{id}` → 204 (하나)
`DELETE /api/me/notifications` → 204 (모두 비우기)

---

## 기존 응답에 필드 추가 (선택, 하위 호환)

아래 필드는 **없어도 앱이 깨지지 않습니다.** 있으면 바로 화면에 나타납니다.

| 엔드포인트 | 추가 필드 | 쓰이는 곳 | 없을 때 |
|---|---|---|---|
| `GET .../daily-question/{id}/answers` → `answers[]` | `createdAt` (ISO-8601) | 답변 카드의 "오후 9:12", "먼저 도착한 답변" 순서 | 시간 숨김, 가족 순서대로 |
| `GET /api/families/me` → `members[]` | `isCreator` (bool) | 구성원 관리 "만든 사람" 배지, 내보내기 권한 | 나만 표시 가능 |
| `GET /api/families/me` | `createdAt` (ISO-8601) | 가족 카드 "함께한 지 128일" | 일수 숨김 |

### 기존 동작 변경 요청

| 엔드포인트 | 요청 |
|---|---|
| `PUT /api/families/me/diary/today` (일지 저장) | **`content`가 빈 문자열이어도 저장**되게 해 주세요. 일지 탭에서 날씨 칸을 누르면 날씨만 바로 저장합니다 ("오늘의 날씨를 남겼어요"). |

---

## 확인이 필요한 문구

새 디자인에 아래 시각이 적혀 있습니다. 실제 서버 스케줄과 맞는지 확인해 주세요.

| 문구 | 위치 |
|---|---|
| "매일 03:00" 질문 도착, "오늘 03:00에 도착한 질문부터 함께 답해요" | 알림 설정, 참여 완료 화면, 사용 방법 안내 |
| "매일 02:50 결과" (가족 온도 변화) | 알림 설정 |
