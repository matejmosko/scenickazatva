# Todo

## Done
- [x] Festival Game (quiz like) — implemented in develop (text/abc/sort/match, admin editor, results + winner pick)
- [x] Fix timestamp editing — event datetime editing fixed + unit-tested (`test/event_datetime_test.dart`)

---

## Future ideas

### Stability & reliability
- [ ] Replace the stale `test/widget_test.dart` counter boilerplate with a real smoke test (mock Firebase/Hive) so `flutter test` is green and CI can gate on it.
- [ ] Add `integration_test/` coverage for core flows: login → browse program → open event → submit a game answer.
- [ ] Run `flutter analyze` + `flutter test` in Codemagic on every PR/tag; add a pre-push hook.
- [ ] Fix the web icon tree-shaking trade-off: DB-driven venue/info icons render blank on web after 99% font tree-shaking. Options: curated codepoint→`Icons.*` mapping, or standardize `--no-tree-shake-icons` in deploy docs/script.
- [ ] Audit Realtime DB security rules (new game nodes included): read/write rules for `festivals/{id}/game`, `users/{uid}/game`, participant `winner` flag (server-writable only), `appsettings`. Run the security-rules-auditor skill on changes.
- [ ] Add Firebase Crashlytics + a central error-reporting wrapper; replace bare `debugPrint` in services (NotificationService, ImagePrecacheService, providers) with structured logging.
- [ ] Server-side deadline enforcement for the game (Cloud Function): freeze submissions at `endsAt`, verify `winner` picks against scores.
- [ ] Offline-first hardening: submission queue for game answers/favorites when offline; connectivity banner; document which features work offline (RTDB cache + Hive already help).
- [ ] Schema/version guards for Hive boxes and RTDB shapes so stale app versions degrade gracefully instead of throwing.
- [ ] Add unit tests for Cloud Functions (`functions/`): `checkNewArticles` poll dedup, payload shape, FCM topic send.
- [ ] Deep-link (app_links) cold-start + web route tests; verify `/news/`, `/events/`, `/game` links on all platforms.

### Features
- [ ] "My program": favorite events → personal schedule tab + opt-in local notifications before each event (uses existing flutter_local_notifications + timezone).
- [ ] Calendar export (iCal / Google Calendar) of the festival program.
- [ ] Event search + filters (date, venue, category); sort options in calendar view.
- [ ] Home/highlights screen: countdown to festival, featured events, latest news, game entry — better than the plain tab list.
- [ ] Venue detail page: photo, description, map link / directions (url_launcher), all events at the venue.
- [ ] Share action on events and news (system share sheet with text + URL).
- [ ] News feed improvements: categories/tags filter, "read later" queue, pull-to-refresh, offline reading (Hive already caches — surface it).
- [ ] Game follow-ups: live standings, tie-break by answer time, badges/achievements, share-your-result card, admin "announce winner" push notification.
- [ ] Notification center in-app (history of received notifications, not only magazine updates topic).
- [ ] Photo gallery / "live from festival" user photo uploads (firebase_storage is already a dependency).
- [ ] In-app feedback / report-an-issue form (or link).
- [ ] Multi-language support (SK/EN) via flutter_localizations + ARB for tourists; format dates per locale.
- [ ] Accessibility pass: semantic labels, screen-reader support, text scaling and contrast on key screens (game, calendar, info).
- [ ] PWA polish on web: manifest, offline shell, install prompt, and SEO/og meta tags per news article for social shares.
- [ ] Dark mode: system-follow + manual override in settings (verify current theme handling).
- [ ] Downloadable program PDF / offline copy.

### Content & admin
- [ ] Scheduled publishing for info posts / events (publishAt fields + Cloud Function or client-side filtering).
- [ ] Rich text editor improvements: image upload from admin editor (firebase_storage), paste handling, HTML round-trip checks (flutter_quill + delta conversions are already in place).
- [ ] Multi-festival polish: per-festival theming (accent color/logo from `appsettings/festivals`), per-festival game + news.
- [ ] Analytics funnel: measure event-detail opens, game participation, notification tap-through to tune content.

### Developer experience
- [ ] Move shared inline widgets out of views into `lib/widgets/` (game card, dynamic icon, event tiles) and add a widget test for them.
- [ ] `firebase_functions/` leftover dir at repo root — delete.
- [ ] Add `AGENTS.md` entries for game RTDB paths and the `--no-tree-shake-icons` web caveat.
- [ ] Document the manual staging checklist (firebase deploy, web build, tag release) in README.
