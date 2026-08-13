# Todo

## Done
- [x] Festival Game (quiz like) — implemented in develop (text/abc/sort/match, admin editor, results + winner pick)
- [x] Fix timestamp editing — event datetime editing fixed + unit-tested (`test/event_datetime_test.dart`)
- [x] News feed improvements: categories/tags filter, "read later" queue, pull-to-refresh, offline reading (Hive already caches — surfaced via `fetchPostById` fallback).
    - [x] WordPressService: offline cache fallback (`hitCacheOnNetworkFailure`)
    - [x] NewsProvider: read-later Hive queue + `fetchPostById` reliable fallback
    - [x] NewsProvider: news categories + selection threaded into API calls
    - [x] UI: Category dropdowns, bookmark overlays, and "Read Later" queue page
    - [x] Detail Page: Offline fallback + bookmark toggle
    - [x] Tests: coverage for read-later and category selection logic

---

## Future ideas

### Stability & reliability
- [ ] Add `integration_test/` coverage for core flows: login → browse program → open event → submit a game answer. Scaffold added (`integration_test/app_smoke_test.dart`); needs a device to run.
- [x] Fix the web icon tree-shaking trade-off: DB-driven venue/info icons render blank on web after 99% font tree-shaking. Fixed by standardizing `--no-tree-shake-icons` in the deploy command (AGENTS.md + README).
- [x] Audit Realtime DB security rules (new game nodes included): read/write rules for `festivals/{id}/game`, `users/{uid}/game`, participant `winner` flag (server-writable only), `appsettings`. Audited manually (security-rules-auditor skill not vendored): `participants` writes are now admin/editor-only (server-computed), game submissions are blocked after `game/endsAtMs`, `endsAtMs` got an admin/editor write rule. Run the security-rules-auditor skill on changes if `.agents/skills` is available.
- [x] Add a central error-reporting wrapper; replace bare `debugPrint` in services (NotificationService, ImagePrecacheService, providers) with structured logging. `lib/utils/AppLog.dart` (`info`/`warn`/`error` + `errorHandler` hook), all 84 `debugPrint` call sites replaced, `test/app_log_test.dart`.
- [x] Server-side deadline enforcement for the game: RTDB rule blocks `users/{uid}/game/...` writes once `now > endsAtMs` (new numeric `endsAtMs` field kept in sync with `endsAt` in `GameConfig.toJson`), the client blocks/UI-disables submissions after `endsAt` (`GameProvider.isGameClosed`), and `recomputeParticipant` CF deletes stragglers as defense in depth.
- [x] Offline-first hardening: submission queue for game answers/favorites when offline; connectivity banner; document which features work offline (RTDB cache + Hive already help). `ConnectivityService` (RTDB `.info/connected`) + `ConnectivityBanner` wired into `MaterialApp.router`, README "Offline behavior" section.
- [x] Schema/version guards for Hive boxes and RTDB shapes so stale app versions degrade gracefully instead of throwing. `Preferences` writes `schema_version`, ignores newer-schema data, type-safe reads (`test/hive_preferences_test.dart`).
- [x] Add unit tests for Cloud Functions (`functions/`): `checkNewArticles` poll dedup + payload shape + FCM topic send (`functions/test/articles.test.js`), game deadline + participant recompute logic (`functions/test/gameLogic.test.js`); `npm --prefix functions test` (node:test, no emulator).
- [x] Deep-link (app_links) cold-start + web route tests; verify `/news/`, `/events/`, `/game` links on all platforms. `lib/utils/DeepLinks.dart` normalizer + `test/deep_links_test.dart`, app_links wired in main() (non-web), hosting `rewrites` for SPA routes; device verification still pending.
- [x] Rethink necessity of firebaseappcheck. We do not target web apps, only android and iphone. Web apps are used only in development for quick build checks.

### Features
- [ ] "My program": favorite events → personal schedule tab + opt-in local notifications before each event (uses existing flutter_local_notifications + timezone).
- [ ] Calendar export (iCal / Google Calendar) of the festival program.
- [ ] Event search + filters (date, venue, category);
- [ ] Home/highlights screen: countdown to festival, featured events, latest news, game entry — better than the plain tab list.
- [x] Venue detail page: photo, description, map link / directions (url_launcher), all events at the venue.
- [x] Share action on events and news (system share sheet with text + URL).
- [ ] Notification center in-app (history of received notifications, not only magazine updates topic).
- [ ] Multi-language support (SK/EN) via flutter_localizations + ARB for tourists; format dates per locale.
- [ ] Accessibility pass: semantic labels, screen-reader support, text scaling and contrast on key screens (game, calendar, info).
- [x] Dark mode: system-follow + manual override in settings (verify current theme handling).

### Content & admin
- [x] Rich text editor improvements: image upload from admin editor (firebase_storage), paste handling, HTML round-trip checks (flutter_quill + delta conversions are already in place).
- [x] Multi-festival polish: per-festival theming (accent color/logo from `appsettings/festivals`), per-festival game + news.
- [x] Analytics funnel: measure event-detail opens, game participation, notification tap-through to tune content.

### Developer experience
- [x] Move shared inline widgets out of views into `lib/widgets/` (game card, dynamic icon, event tiles) and add a widget test for them.
- [x] Add `AGENTS.md` entries for game RTDB paths and the `--no-tree-shake-icons` web caveat.
- [x] Document the manual staging checklist (firebase deploy, web build, tag release) in README.
