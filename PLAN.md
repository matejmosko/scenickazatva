# Plan: Live Quiz (Speaker-Controlled Real-Time Game)

## Context

The basic game types (quiz, festival game, form) are implemented. The live quiz is a fundamentally different product: a speaker on stage controls which question players see in real-time. Players can only answer the currently-open question. The speaker has a control panel to advance through questions, with optional per-question time limits.

## Architecture

### Data Model

```
festivals/{fid}/games/{gid}/liveState: {
  currentQuestionId: "abc123",   // which question is active
  isOpen: true,                  // whether players can submit answers
  openedAt: "2026-08-21T10:00:00Z",  // when current question was opened
  timeLimitSeconds: 30,          // optional countdown (0 = no limit)
  controlledBy: "uid_of_speaker" // only this UID can write liveState
}
```

- `liveState` lives at `festivals/{fid}/games/{gid}/liveState` in RTDB
- Written by the speaker panel (admin/editor only)
- Read by all players via existing `onValue` subscription on the game node
- The `controlledBy` field is optional — any admin/editor can control, but if set, only that UID can write

### Game Flow

1. Admin creates a game with `type: "live"` and adds questions
2. Speaker opens the game, navigates to `/game/{id}/live`
3. Speaker clicks "Spustiť" — sets `isOpen: true`, `currentQuestionId` to first question
4. Players see the current question with optional countdown timer
5. Players submit answers (same as quiz type — answer persisted to their submissions)
6. Speaker clicks "Ďalšia" — advances to next question, closes current
7. After last question, speaker clicks "Ukončiť" — sets `isOpen: false`, game status to `"ended"`
8. Results page shows leaderboard (same as quiz type — score-based ranking)

## Files to Change

### 1. GameType enum: `lib/models/GameType.dart`
- Add `live('live', 'Živý kvíz')` to the enum
- `fromId()` fallback stays `GameType.game`

### 2. GameConfig model: `lib/models/GameConfig.dart`
- Add `int timeLimitSeconds` field (default `0` = no limit)
- Add to `fromJson`/`toJson`
- No other changes needed — `type` already handles `"live"` via `GameType.fromId`

### 3. GameEditPage: `lib/pages/GameEditPage.dart`
- Add `"Živý kvíz"` option to the type dropdown
- Add `timeLimitSeconds` input field (visible only for live type)
- Copy `timeLimitSeconds` in the local `_edited` clone
- Description text for live type: "Režisér ovláda otázky v reálnom čase."

### 4. Speaker control panel: new `lib/pages/LiveGameControlPage.dart`
- **Route:** `/game/{id}/live` (admin/editor only)
- **Layout:** vertical ListWrap of question cards + control buttons at bottom
- **Questions list:** shows all questions with index, title, type icon; current question highlighted
- **Control buttons:**
  - "Spustiť" — initializes `liveState` with first question, `isOpen: true`
  - "Ďalšia otázka" — advances `currentQuestionId` to next question, `isOpen: true`
  - "Zavrieť" / "Otvoriť" — toggles `isOpen`
  - "Ukončiť hru" — sets `isOpen: false`, game status to `"ended"`
- **Timer display:** shows countdown based on `openedAt + timeLimitSeconds` (updates every second via `Timer.periodic`)
- **Player count:** live count from `participants` node
- **RTDB writes:** writes to `festivals/{fid}/games/{gid}/liveState` via `FirebaseDatabase.instance.ref(...).update(...)`
- **Lock:** the `controlledBy` field is set to current admin UID on first write; subsequent writes validate `auth.uid == controlledBy` (client guard + rules)

### 5. Player live view: `lib/pages/GamePage.dart`
- In `_buildBody`: add `GameType.live` case → `_buildLiveBody()`
- **`_buildLiveBody()`:**
  - Subscribes to `liveState` via `FirebaseDatabase.instance.ref("festivals/$fid/games/$gid/liveState").onValue`
  - Shows spinner while waiting for first `liveState` event
  - When `isOpen: false` → "Čakajte na ďalšiu otázku..." message with countdown to next question
  - When `isOpen: true` → renders current question inline (same as quiz form input widgets)
  - **Timer:** countdown bar based on `openedAt + timeLimitSeconds`; when reaches 0, auto-submit current answer and show "Čas vypršal"
  - **Submit:** single "Odoslať" button per question (not batch — one question at a time)
  - **After submit:** shows "Čakajte na ďalšiu otázku..." until next question opens
  - **Score:** optional real-time score display at top (correct count / total so far)
- **Existing quiz/form state maps** (`_textControllers`, `_selectedIndexes`, etc.) reused for the current question input
- **Cleanup:** cancel `liveState` subscription and timer in `dispose`

### 6. GameProvider: `lib/providers/GameProvider.dart`
- Add `_liveStateListener` stream subscription
- Add `liveState` map field: `{currentQuestionId, isOpen, openedAt, timeLimitSeconds}`
- Add `listenToLiveState(gameId)` method — subscribes to `festivals/$fid/games/$gid/liveState`
- Add `stopLiveStateListener()` method
- Wire `listenToLiveState` into `selectGame` when type is `live`
- `submitAnswer` already handles all types — no changes needed (live submissions scored same as quiz)

### 7. RTDB rules: `database.rules.json`
- Add `"live"` to the `type` validation: `(newData.val() == 'quiz' || newData.val() == 'game' || newData.val() == 'form' || newData.val() == 'live')`
- Add `liveState` validation under `$gameId`:
  ```json
  "liveState": {
    ".write": "auth != null && root.child('users/' + auth.uid + '/userRole').val() == 'admin' || root.child('users/' + auth.uid + '/userRole').val() == 'editor'",
    "currentQuestionId": { ".validate": "newData.isString()" },
    "isOpen": { ".validate": "newData.isBool()" },
    "openedAt": { ".validate": "newData.isString()" },
    "timeLimitSeconds": { ".validate": "!newData.exists() || newData.isNumber()" },
    "controlledBy": { ".validate": "!newData.exists() || newData.isString()" }
  }
  ```

### 8. GamesListPage: `lib/pages/GamesListPage.dart`
- No changes needed — existing `_statusLabel`/`_statusColor` already handles all statuses
- The game card already shows question count and status chip

### 9. GameResultsPage: `lib/pages/GameResultsPage.dart`
- Already handles quiz-type ranking (score-based) — no changes needed for live quiz

### 10. Cloud Functions: `functions/gameLogic.js`
- `computeParticipantUpdate`: already handles all submission types correctly (scores correct answers, counts all submissions). Live quiz submissions are identical to quiz submissions — each answer has `correct` and `points` fields. No changes needed.

### 11. Analytics: `lib/requests/AnalyticsEvents.dart`
- Add `liveGameStarted`, `liveGameQuestionOpened`, `liveGameQuestionClosed` events

### 12. Router: `lib/main.dart`
- Add route `/game/:gameId/live` → `LiveGameControlPage`
- Guard: admin/editor only (check `UserProvider.canEdit`)

### 13. Tests
- `test/game_test.dart`: add `GameType.live` round-trip, `GameConfig` with `timeLimitSeconds`
- `test/game_test.dart`: add `liveState` serialization tests
- Widget test for speaker control panel buttons
- Widget test for player live view states (waiting, answering, submitted)

## Implementation Order

1. **GameType enum + GameConfig model** — add `live` type and `timeLimitSeconds` field
2. **RTDB rules** — add `live` to type validation, add `liveState` node validation
3. **GameProvider** — add `liveState` subscription + fields
4. **GamePage** — add `_buildLiveBody()` for player view
5. **LiveGameControlPage** — new speaker control panel
6. **Router** — add `/game/:gameId/live` route
7. **GameEditPage** — add live type option + time limit input
8. **Analytics** — add new events
9. **Tests + lint + analyze**
10. **Deploy rules + functions**

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Network latency (100–500ms) causes player to see stale question | Players answer wrong question | Show "Načítavam..." during transitions; speaker should pause 1–2s between questions |
| Multiple admins open speaker panel simultaneously | Conflicting writes to `liveState` | `controlledBy` field locks to first writer; other admins see read-only view |
| Player goes offline during live quiz | Misses question window | Show `ConnectivityBanner` (already exists); player sees "Čakajte na ďalšiu otázku..." when reconnecting |
| Timer drift between speaker and player clocks | Player's countdown differs from speaker's | Use `openedAt` absolute timestamp + `timeLimitSeconds` — each device computes remaining time locally from the same reference |
| Speaker accidentally advances past a question | Players can't go back | Add confirmation dialog on "Ďalšia otázka"; no back button by design (live quiz is forward-only) |

## Verification

- `flutter analyze` — no issues
- `flutter test` — all pass
- `npm --prefix functions run lint` — clean
- `npm --prefix functions test` — all pass
- Manual: create live game, open speaker panel, advance through questions
- Manual: player view shows current question, submits answer, sees waiting screen
- Manual: timer counts down, auto-submits on expiry
- Manual: speaker ends game, results page shows leaderboard
- Manual: non-admin cannot access speaker panel
