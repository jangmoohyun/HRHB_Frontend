# 하루한번 VER2 — 백엔드 추가 API 명세

> 대상: 백엔드 개발자
> 프론트엔드는 아래 API를 **이미 호출하도록 구현되어 있습니다.** 지금은 샘플 데이터로 동작하며, 서버에 이 명세대로 엔드포인트가 생기면 스위치 하나로 실제 데이터로 바뀝니다.

## 연결 방법 (프론트엔드)

```bash
# 실제 API 사용
flutter run --dart-define=HARU_PENDING_DUMMY=false
```

또는 [lib/data/pending/pending_api.dart](lib/data/pending/pending_api.dart)의 `kPendingUseDummy` 기본값을 `false`로 바꿉니다.
**스토어 배포 전 반드시 `false`여야 합니다** — 샘플 데이터(스트릭 12일, 참여율 92% 등)는 실제 사용자 데이터가 아닙니다.

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

홈 상단 "🔥 12일째" 칩, 연속 답변 미니카드, 연속 답변 시트에 쓰입니다.

```json
{
  "currentStreak": 12,
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
| `answeredToday` | bool | 오늘 질문에 내가 답했는지 |
| `week` | array(7) | **이번 주 월요일 → 일요일**. 미래 날짜는 `false` |

---

### P2. 날짜별 답변 현황

`GET /api/families/me/daily-question/answer-status?year=2026&month=9`

홈의 주간 날짜 스트립(내 답변 점), 기록 탭 날짜별 목록(구성원 점 + "3/4")에 쓰입니다.

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

### P3. 주간 리포트

`GET /api/families/me/reports/weekly?weekStart=2026-09-21`

기록 > 리포트 > 주간. `weekStart`는 항상 월요일입니다.

```json
{
  "periodStart": "2026-09-21",
  "periodEnd": "2026-09-27",
  "answerRate": 71,
  "previousAnswerRate": 60,
  "members": [
    { "userId": 11, "answered": [true, true, false, true, true, null, null] },
    { "userId": 12, "answered": [true, true, true, true, false, null, null] }
  ],
  "temperatureChanges": [
    { "date": "2026-09-20", "delta": 0.3 },
    { "date": "2026-09-21", "delta": -0.2 }
  ],
  "temperatureSum": 0.7,
  "highlights": [
    { "type": "FIRST_RESPONDER", "title": "엄마가 가장 먼저 답했어요", "subtitle": "이번 주 5번 중 4번" },
    { "type": "LONGEST_ANSWER", "title": "가장 긴 답변이 나온 질문", "subtitle": "가족에게 고마웠지만 말하지 못한 순간이 있나요?" }
  ]
}
```

| 필드 | 타입 | 설명 |
|---|---|---|
| `answerRate` | int (0–100) | 기간 중 **지나간 날**의 (답한 칸 수 ÷ 전체 칸 수) × 100 |
| `previousAnswerRate` | int \| null | 지난주 같은 기준. 없으면 null (문구 숨김) |
| `members[].answered` | (bool\|null)[7] | 월→일. **아직 오지 않은 날은 `null`** (점선 칸으로 표시) |
| `temperatureChanges` | array | 막대 차트. 최근 6개 권장 |
| `temperatureSum` | number | "합계 +0.7°C" |
| `highlights[].type` | string | `FIRST_RESPONDER` → ⚡ 노란 타일, `LONGEST_ANSWER` → 💬 분홍 타일, 그 외 → ★ |
| `highlights[].title/subtitle` | string | **서버가 완성 문장으로** 내려줍니다 (조사 처리 포함) |

---

### P4. 월간 리포트

`GET /api/families/me/reports/monthly?year=2026&month=9`

기록 > 리포트 > 월간 (히트맵).

```json
{
  "year": 2026,
  "month": 9,
  "answerRate": 68,
  "previousAnswerRate": 62,
  "memberCount": 4,
  "days": [
    { "date": "2026-09-01", "answeredCount": 3 },
    { "date": "2026-09-26", "answeredCount": null }
  ],
  "temperatureChanges": [ { "date": "2026-09-25", "delta": 0.5 } ],
  "temperatureSum": 1.9,
  "highlights": [ { "type": "FIRST_RESPONDER", "title": "...", "subtitle": "9월 25번 중 17번" } ]
}
```

| 필드 | 타입 | 설명 |
|---|---|---|
| `memberCount` | int | 히트맵 단계 계산용 (단계 = round(답한 수 ÷ 구성원 수 × 4)) |
| `days` | array | **1일부터 말일까지 전부**. 미래 날짜는 `answeredCount: null` |

---

### P5. 구성원별 이번 달 참여율

`GET /api/families/me/participation?year=2026&month=9`

가족 탭 "이번 달 참여" 게이지 카드.

```json
{
  "members": [
    { "userId": 11, "answerRate": 92 },
    { "userId": 12, "answerRate": 100 }
  ]
}
```

앱이 표시하는 문구: 100% "빠짐없이 답해요", 90% 이상 "꾸준해요", 70% 이상 "잘 이어가요", 70% 미만 "조금 더 힘내요"(주황 경고).

---

### P6. 알림 목록

`GET /api/me/notifications?page=0&size=30`
`POST /api/me/notifications/read-all` → 204

홈 상단 🔔 (안 읽은 알림이 있으면 주황 점), 알림 화면.

```json
{
  "items": [
    {
      "id": 101,
      "type": "ANSWER_POSTED",
      "message": "엄마가 오늘의 질문에 답변을 남겼어요.",
      "createdAt": "2026-09-25T08:10:00+09:00",
      "read": false,
      "target": { "date": "2026-09-25" }
    },
    {
      "id": 96,
      "type": "ALBUM_PHOTOS_ADDED",
      "message": "'추석' 앨범에 사진 7장이 올라왔어요.",
      "createdAt": "2026-09-20T19:00:00+09:00",
      "read": true,
      "target": { "albumId": 4 }
    }
  ],
  "hasMore": false,
  "unreadCount": 3
}
```

| `type` | 눌렀을 때 이동 | `target` |
|---|---|---|
| `QUESTION_ARRIVED` | 홈 | `date` |
| `ANSWER_POSTED` | 그 날의 답변 보기 | `date` |
| `TEMPERATURE_CHANGED` | 가족 온도 상세 | — |
| `DIARY_POSTED` | 기록 > 하루 상세 | `date` |
| `ALBUM_PHOTOS_ADDED` | 앨범 상세 | `albumId` |

기존 FCM 푸시와 **같은 이벤트를 알림 목록에도 저장**하면 됩니다. 알림 화면을 연 뒤 약 1.8초 후 앱이 `read-all`을 호출합니다.

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

## 기존 응답에 필드 추가 (선택, 하위 호환)

아래 필드는 **없어도 앱이 깨지지 않습니다.** 있으면 바로 화면에 나타납니다.

| 엔드포인트 | 추가 필드 | 쓰이는 곳 | 없을 때 |
|---|---|---|---|
| `GET .../daily-question/{id}/answers` → `answers[]` | `createdAt` (ISO-8601) | 답변 카드의 "오후 9:12", "먼저 도착한 답변" 순서 | 시간 숨김, 가족 순서대로 |
| `GET .../daily-question`, `.../today` | `sequenceNumber` (int) | 질문 카드의 "#128" | 번호 숨김 |
| `GET /api/families/me` → `members[]` | `isCreator` (bool) | 구성원 목록 "만든 사람" 배지 | 나만 표시 가능 |

---

## 확인이 필요한 문구

시안의 "가족 온도란?" 안내문이 **"매일 새벽 2시 50분에 전날 참여율·답변 길이·사진 첨부를 보고"** 라고 되어 있습니다. 기획안에는 "오전 3시, 답변 유무·답변 길이"로 적혀 있어요. 실제 서버 계산 방식과 맞는지 확인해 주세요. 문구 위치: [temperature_screen.dart](lib/screens/family/temperature_screen.dart) `_info()`.
