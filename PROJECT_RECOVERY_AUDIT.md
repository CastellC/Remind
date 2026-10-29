# Evidence iOS — Project Recovery Audit

**Audit date:** 2026-10-28 (Pacific/Honolulu)  
**Auditor role:** Senior iOS / technical lead (read-only recovery pass)  
**Repository:** `https://github.com/castellc/remind`  
**Commit audited:** `5fd214c` — *Sync app branding and accent with Remind Figma updates* (2026-07-29 UTC)  
**Working tree:** clean on `main`, in sync with `origin/main` (0 ahead / 0 behind)

> This document is an inventory and risk assessment only. **No product fixes were implemented** as part of this audit.

---

## 1. Current project status

### Verdict

The codebase is a **substantial native SwiftUI MVP** (~14k LOC Swift across ~110 tracked Swift files), offline-first with optional Supabase. Architecture matches the stated product requirements (SwiftUI + SwiftData + repository protocols + service layer). Development paused mid-hardening after Figma branding sync (“Remind”) and a series of compile fixes.

**Recommendation up front:** **Continue the existing codebase.** Do not rebuild. Selective refactor of sync breadth and auth completion is warranted; wholesale rewrite is not justified.

### Repository inspection

| Item | Finding |
| --- | --- |
| Project root | `/workspace` (clone of `castellc/remind`) |
| Git | Initialized; remotes: `origin` → GitHub |
| Current branch | `main` |
| Uncommitted changes | None |
| Ahead / behind remote | **0 / 0** vs `origin/main` |
| Last 10 commits | Branding sync → several Swift compile/API fixes → XCTest coverage → Xcode generator → app shell → design system → services → models → Supabase schema |
| Accidentally tracked secrets | **None found.** `Config.xcconfig` is gitignored; tracked files use placeholders / empty defaults. No service-role keys, `.p8`, or `.env` in git. |
| Junk in tree | Root `testtest` (HTML stub) — unrelated leftover |
| Open draft PR | [#3](https://github.com/castellc/remind/pull/3) *Fix PhotosPicker MainActor isolation* — **still OPEN**, not on `main` |

### iOS project inspection

| Item | Finding |
| --- | --- |
| Xcode project | `Evidence.xcodeproj` (objectVersion 77, Xcode 16.0 compatibility). **No `.xcworkspace` app workspace**; SPM is project-attached. |
| Shared schemes | **Missing** `xcshareddata/xcschemes` — Xcode will auto-create a local scheme named from the target; CI/`xcodebuild -scheme Evidence` may fail until a shared scheme is committed. |
| Targets | `Evidence` (app), `EvidenceTests`, `EvidenceUITests` |
| Deployment target | **iOS 18.0** |
| Swift language mode | **5.0** (`SWIFT_VERSION = 5.0`) |
| Package deps | Single SPM: `supabase-swift` ≥ **2.0.0** (upToNextMajor). No `Package.resolved` committed (gitignored). |
| SwiftData | Configured via `ModelContainer.evidence()` with full model schema (profile, entries, tags, categories, check-ins, sessions, feedback, reminders, meaningful dates, guided content). |
| Entry point | `Evidence/App/EvidenceApp.swift` → `AppContainer` / `AppEnvironment` → `RootView` (lock → onboarding → tabs) |
| Architecture | Native SwiftUI feature folders + `@Observable` VMs + repository protocols + local SwiftData repos + optional Supabase remotes. **Matches** stated native requirements (no RN/Flutter/web shell). |
| Signing | Automatic; `DEVELOPMENT_TEAM` empty; Sign in with Apple entitlement present. |
| Display name / brand | **Split identity:** UI copy / theme brand = **Remind**; Xcode `CFBundleDisplayName`, target, bundle id (`com.evidence.app`), Face ID string in `pbxproj` still say **Evidence**. |

### Environment note (this audit host)

This audit ran on **Linux**. `xcodebuild` / Swift toolchain / iOS Simulator are **not available**. Build and test results below are inferred from project structure, source review, README claims, and open PR evidence — not from a green local build on this machine.

---

## 2. What is working

These areas look **implemented with supporting unit tests and coherent architecture**. Treat as “working in code” until macOS verification:

| Area | Evidence |
| --- | --- |
| App shell / routing | `EvidenceApp`, `RootView`, `MainTabView`, `AppRoute` |
| Theme / components | Design tokens, buttons, cards, choice controls, FeedbackBar, SafetySupportView |
| SwiftData models + local repos | Full local persistence path; preview/test containers |
| Onboarding UI | Multi-step skippable flow (`OnboardingContainerView` + steps) |
| Today | Check-in CTA, empty states, gentle suggestion, navigation |
| Collection | Search, filters, archive, favorites (covered partly by search tests) |
| Entry editor (structure) | Text/image types, meaning prompts, tags/categories wiring |
| Check-in flow | Emotion → support need → intensity → recommendation / safety |
| Recommendation engine | Large deterministic scorer + extensive `RecommendationEngineTests` |
| Feedback model + UI | `FeedbackBar` + feedback repository + engine weighting |
| Safety language detector | Phrase detection + `SafetyLanguageDetectorTests` |
| Local notifications scheduling | Builder + tests (authorization requested in settings / onboarding, not cold launch) |
| App lock service / UI | LAContext path, privacy cover, settings |
| Local image storage + orphan cleanup | Services + `ImageOrphanCleanupTests` |
| Export ZIP + deletion services | Local export/delete implemented; unit tests for local deletion |
| Offline-first posture | App runs without Supabase credentials (`Unavailable*` / stub remotes) |
| Supabase SQL artifacts | Schema, RLS, private `evidence-media` bucket migrations present in repo |
| Unit test volume | ~1.2k LOC tests across auth, sync conflicts, search, notifications, safety, recommendation, images, deletion |

---

## 3. What is incomplete

| Area | Gap |
| --- | --- |
| Cloud sync breadth | `SyncCoordinator` only push/pull/deletes **`evidence_entries` (+ media)**. Remote facades exist for tags, categories, check-ins, feedback, profile, reminders, meaningful dates — **not wired into the coordinator**. |
| Account deletion RPC | Client calls `rpc("delete_user_account")` but **no migration defines that function**. |
| Magic-link deep link | Supabase `config.toml` lists `com.evidence.app://auth-callback`, but the **iOS project has no URL types / `onOpenURL` handler**. Magic link send exists; return path does not. |
| Sign in with Apple hardening | Nonce is set as **raw** string on `ASAuthorizationAppleIDRequest.nonce` (typically should be SHA-256 of the raw nonce). Live Apple/Supabase auth is unverified. |
| PhotosPicker concurrency fix | Open draft PR #3 not merged; `EntryEditorView` still references `viewModel.pickedImage` inside the PhotosPicker label (likely **MainActor/`@Sendable` compile failure** on current Xcode). |
| Shared Xcode scheme | Not committed; hurts CLI/CI. |
| Branding unification | Remind vs Evidence inconsistency across UI, Info.plist, Face ID string, README title. |
| Photo library usage string | Not required for limited PhotosPicker selection, but **no** `NSPhotoLibrary…` keys if broader access is added later. |
| `Config.xcconfig` | Not present in repo (expected); cloud features need local creation. |
| Hosted Supabase project | Not inspectable from this environment; migrations exist but **application status unknown**. |
| UI tests | Scaffolding / soft assertions only — not a verification suite. |
| Accessibility device pass | Components are a11y-aware; full VoiceOver / largest Dynamic Type / Voice Control passes still open (documented in README). |
| App icon | Asset slot exists; marketing 1024 icon may be unfinished. |
| Trusted-contact safety path | UI can exist with `trustedContactAvailable: false` — not product-complete. |
| Future roadmap | Audio/video, share extension, OCR, widgets, Android — correctly out of scope. |

---

## 4. What is broken (or likely broken)

| Item | Severity | Notes |
| --- | --- | --- |
| PhotosPicker MainActor isolation on `main` | **High (compile)** | Unmerged fix on `cursor/fix-photospicker-sendable-6949`. Expect entry-editor build failure until merged or reapplied. |
| Cloud sync incomplete for relational data | **High (product)** | Synced entries without tags/meaning relationships degrade recommendations after restore on a second device. |
| Account deletion | **High (compliance/trust)** | Will fail without server RPC; risk of false confidence if UI claims success without distinguishing errors (service does try to surface errors — verify UX copy). |
| Magic-link completion | **Medium** | Send may work; returning users via email link will stall without URL scheme + session handling. |
| Apple Sign In nonce hashing | **Medium** | May fail Supabase/Apple validation in production. |
| No shared scheme / Linux CI | **Medium (process)** | Cannot verify build in this environment; local macOS required. |
| Branding / Face ID string drift | **Low–Medium** | Confusing for App Store / privacy prompts (“Evidence” vs “Remind”). |

Nothing in the audited tree indicates a total architectural dead end. “Broken” items are concentrated in **cloud completion** and **unmerged compile fixes**.

---

## 5. Feature inventory (classification)

Legend:

- **Implemented and verified** — code + meaningful automated tests (still needs macOS/device confirmation)
- **Implemented but unverified** — substantial UI/service code; little or no automated proof / needs live config
- **Partially implemented** — core path present with known gaps
- **Not implemented** — absent or explicitly out of scope
- **Broken** — known compile/runtime failure or missing critical dependency

| Feature | Classification | Notes |
| --- | --- | --- |
| Onboarding | Implemented but unverified | Full skippable steps; UITests soft only |
| Authentication | Partially implemented | Apple + magic-link UI/services; nonce, URL callback, dashboard config incomplete |
| Today screen | Implemented but unverified | Complete feature UI |
| Collection | Implemented and verified* | Search/filter unit tests; UI flows soft |
| Entry create/edit | Partially implemented / **likely Broken** | Feature rich; PhotosPicker isolation issue on `main` |
| Image imports | Partially implemented | Local store + a11y description; cloud media path exists; picker compile risk |
| Check-ins | Implemented but unverified | Full 3-step flow + safety handoff |
| Recommendation engine | Implemented and verified* | Strong unit coverage |
| Feedback | Implemented and verified* | UI + engine integration tested indirectly |
| Notifications | Implemented and verified* | Schedule builder tests; live permission/scheduling unverified on device |
| App lock | Implemented but unverified | Needs device biometrics |
| Export | Implemented but unverified | Local ZIP export service + UI |
| Deletion (local) | Implemented and verified* | Unit tests |
| Deletion (cloud / account) | Partially implemented / **Broken** without RPC | |
| Accessibility | Partially implemented | Good component patterns; device audits pending |
| Offline sync | Partially implemented | Entries-only coordinator; conflict resolver tested |
| Supabase RLS/storage SQL | Implemented but unverified | Present in repo; not confirmed applied remotely |

\*“Verified” means automated unit coverage exists, not that a release QA pass was completed.

---

## 6. Security or data-loss risks

1. **No tracked secrets** — good. Keep `Config.xcconfig` gitignored; never commit anon keys to history.
2. **RLS + private bucket designed correctly in SQL** — risk is operational: if migrations were never applied on the hosted project, a misconfigured open bucket would be catastrophic. Confirm before enabling sync for real users.
3. **Account deletion incomplete** — users may believe cloud account/data is gone when RPC fails.
4. **Sync scope gap** — restoring another device can look “synced” while tags/check-ins/feedback/reminders remain local-only → silent data divergence.
5. **Conflict copies** — timestamp merge + “local copy” can duplicate sensitive content; acceptable for MVP but document for users.
6. **Sign-out preserves local data** — intentional; ensure Settings copy stays unambiguous so users do not confuse sign-out with wipe.
7. **Keychain** — stores user-id hint only; session expected in Supabase SDK storage — confirm SDK persistence behavior on reinstall.
8. **Safety detector** — conservative phrase matching only; must not be marketed as crisis intervention. No country hotlines by design.

---

## 7. Missing configuration

| Config | Status |
| --- | --- |
| `Evidence/Configuration/Config.xcconfig` | Missing (gitignored); required for cloud |
| Apple Developer Team (`DEVELOPMENT_TEAM`) | Empty |
| Sign in with Apple (App ID + Supabase provider) | Manual dashboard work |
| Email auth + redirect URLs | Manual; iOS URL scheme not wired |
| Hosted Supabase project + applied migrations | Unknown |
| `delete_user_account` RPC / Edge Function | **Missing from migrations** |
| Shared Xcode scheme | Missing from repo |
| `Package.resolved` | Intentionally gitignored — first resolve on each machine |
| Production Universal Links | Not configured |

*(Secret values intentionally omitted.)*

---

## 8. Build and tests (this environment)

| Check | Result |
| --- | --- |
| Clean `xcodebuild` | **Not possible** (Linux host, no Xcode) |
| Automated tests | **Not executed here** |
| Dependency freshness | supabase-swift pinned to ≥2.0.0 without resolved snapshot — resolve on macOS and review current major |
| Expected compile blocker on `main` | PhotosPicker label MainActor issue (open PR #3) |
| README accuracy | Correctly documents Linux limitation and offline-first behavior |

**Next verification (on macOS / Xcode 16+):**

```bash
# After merging or cherry-picking the PhotosPicker fix and adding a shared scheme:
xcodebuild test \
  -project Evidence.xcodeproj \
  -scheme Evidence \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## 9. Recommended fixes (priority order)

Do **not** implement these in the audit pass; sequence for resumption:

1. **P0 — Unblock compile:** Merge or reapply PR #3 PhotosPicker MainActor fix; confirm clean build on Xcode 16+.
2. **P0 — Shared scheme:** Commit `Evidence.xcscheme` under `xcshareddata` so CLI/CI work.
3. **P0 — Branding decision:** Choose Remind vs Evidence for display name, Face ID string, README title, and generator script; apply consistently (bundle id change is a separate, costly decision — keep `com.evidence.app` unless shipping rename is intentional).
4. **P1 — Auth completion:** Hash Apple nonce correctly; add URL scheme / callback handling for magic links; document Apple + Supabase dashboard checklist and verify on device.
5. **P1 — Account deletion:** Add `delete_user_account` migration/Edge Function (service role server-side only) or disable/hide account-delete UI until ready.
6. **P1 — Sync breadth:** Extend `SyncCoordinator` to push/pull tags, join tables, check-ins, feedback, profile flags, reminders (or explicitly document entries-only sync and gate “cloud restore” claims).
7. **P2 — Confirm remote backend:** Apply/verify migrations + RLS + private bucket on the real Supabase project; smoke-test upload path `<user_id>/…`.
8. **P2 — UITest hardening:** Replace scaffolding with assertions for onboarding skip, check-in happy path, entry save.
9. **P2 — Accessibility device pass** on largest content size + VoiceOver for Today / Check-in / Collection / Settings.
10. **P3 — Cleanup:** Remove `testtest`; consider committing `Package.resolved` for reproducible builds; finish app icon.

---

## 10. Smallest next milestone to resume development

**Milestone M0 — “Green local build on macOS” (½–1 focused engineering day)**

Acceptance criteria:

1. PhotosPicker fix on `main`.
2. Shared `Evidence` scheme committed.
3. `xcodebuild build` + `EvidenceTests` pass on iOS 18 simulator.
4. App launches offline through onboarding → Today without Supabase config.
5. Written note of Remind vs Evidence branding decision (even if rename deferred).

Only after M0: **M1 — Auth + sync honesty** (either finish cloud paths or clearly disable incomplete cloud UI).

---

## 11. Continue / refactor / rebuild?

| Option | Recommendation |
| --- | --- |
| **Continue existing codebase** | **Yes — primary path.** Architecture, domain models, recommendation engine, SwiftData schema, and RLS design are assets worth keeping. |
| **Refactor selected components** | **Yes — targeted.** SyncCoordinator breadth, auth nonce/callback, account-deletion server path, branding consistency. Not a layer rewrite. |
| **Rebuild** | **No.** No strong technical justification. A rewrite would discard tested recommendation/safety/sync-conflict logic and reintroduce months of product risk without solving the real blockers (auth wiring, sync completeness, compile fix). |

**Final recommendation:** Resume on `main` with **M0 (green build)** immediately, then prioritize auth correctness and sync scope before any new feature work.
