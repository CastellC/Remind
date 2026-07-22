# Evidence

Private iOS app that helps you preserve and retrieve meaningful evidence of who you are during moments of anxiety, low mood, loneliness, self-criticism, overwhelm, shame, uncertainty, or emotional distress.

> When my current emotional state makes it difficult to remember my value, capabilities, relationships, or resilience, help me retrieve credible and personally meaningful evidence.

## Product purpose

Evidence treats saved content as **meaningful evidence**, not a media gallery. Every personal item includes an explicit explanation of why future you may need it. During check-ins, the app surfaces one relevant item at a time based on the tags and meaning you chose — never random nostalgia.

Useful examples: a thank-you from a friend, praise from a mentor, a photo tied to feeling supported, a personal accomplishment, a note from your steadier self, a grounding technique that helped before.

## Product non-goals

Evidence is **not**:

- A general photo-memory or chronological nostalgia app
- A social network
- A medical diagnostic tool or crisis counselor
- A replacement for professional care
- A generic affirmation feed
- An AI that infers diagnoses, trauma, personality, or motives

The app does not claim to treat, cure, prevent, or diagnose medical conditions. It does not surface random vacation photos, untagged images, or “on this day” memories merely because they exist.

## Native iOS stack

| Layer | Technology |
| --- | --- |
| UI | SwiftUI, NavigationStack |
| Persistence | SwiftData (offline-first) |
| Auth / backend | Official [Supabase Swift SDK](https://github.com/supabase/supabase-swift) (≥ 2.0.0) |
| Notifications | UserNotifications (local) |
| App lock | LocalAuthentication |
| Images | PhotosPicker + Application Support file storage |
| Tests | XCTest (`EvidenceTests`, `EvidenceUITests`) |

**Not used:** React Native, Flutter, Capacitor, web views as the primary UI, or other cross-platform UI frameworks.

**Targets:** iOS 18.0+, iPhone-first (iPad layouts where SwiftUI provides them naturally). Bundle ID: `com.evidence.app`.

## Architecture

Feature-oriented MVVM-style separation:

```
SwiftUI views → feature view models → repository protocols
                                      ├─ SwiftData local repositories
                                      └─ Supabase remote repositories
Services: SyncCoordinator, Authentication, RecommendationEngine,
          NotificationService, LocalImageStorage, SupabaseMedia,
          Export, DataDeletion, SafetyLanguageDetector, AppLock
```

- Views read local SwiftData / `AppContainer` state — not live network calls.
- Supabase is optional; the app works fully in local-only mode when credentials are absent.
- Secrets are never hardcoded. `SUPABASE_URL` and `SUPABASE_ANON_KEY` come from Info.plist keys injected via xcconfig.

Entry point: `Evidence/App/EvidenceApp.swift` → `AppContainer` / `AppEnvironment` → `RootView` (onboarding, lock, tabs).

## Repository structure

```
Evidence/                 App sources (SwiftUI features, models, services)
  App/                    EvidenceApp, RootView, AppContainer, routing
  Features/               Today, Collection, CheckIn, Recommendations, …
  Models/                 SwiftData models, remote DTOs, enums
  Repositories/           Protocols + local/remote implementations
  Services/               Sync, auth, scoring, media, export, safety, …
  Components/             Reusable accessible UI
  DesignSystem/           Theme + typography
  Resources/              Assets, Localizable.xcstrings, guided/safety JSON
  Configuration/          Evidence.xcconfig, Config.example.xcconfig
  Evidence.entitlements   Sign in with Apple
EvidenceTests/            Unit tests
EvidenceUITests/          UI tests (target wired; add flows as needed)
Supabase/                 migrations/, seed.sql, config.toml
Evidence.xcodeproj/       Generated Xcode 16 project
scripts/generate_xcode_project.py
docs/SETUP.md             Condensed Supabase + Apple + Config setup
```

## Xcode / iOS requirements

- **macOS** with **Xcode 16+** (project uses `PBXFileSystemSynchronizedRootGroup`, objectVersion 77)
- iOS **18.0** deployment target
- Swift **5.0** language mode (compatible with Xcode 16 toolchains)
- Apple Developer team for device runs and Sign in with Apple
- Network access once to resolve the Supabase Swift package

> **Linux / this cloud agent environment cannot run `xcodebuild`.** Builds and simulator tests require macOS.

## Setup

1. Clone the repo and check out the feature branch (see [Git workflow](#git-workflow)).
2. Open `Evidence.xcodeproj` in Xcode 16+.
3. Select the **Evidence** scheme and an iOS 18 simulator or device.
4. Set your **Team** under Signing & Capabilities (Automatic signing; `DEVELOPMENT_TEAM` is empty in the project).
5. Create `Config.xcconfig` (below) if you want cloud sync — optional for local-only use.
6. Build and run (⌘R).

To regenerate the Xcode project after structural changes:

```bash
python3 scripts/generate_xcode_project.py
```

## Supabase project setup

1. Create a Supabase project.
2. Copy the **Project URL** and **anon (public) key** — never the service-role key.
3. Enable Auth providers you need (Apple, Email).
4. Apply migrations, storage, and RLS as below.
5. Put URL + anon key into `Evidence/Configuration/Config.xcconfig`.

Local CLI (optional):

```bash
# From repo root, with Supabase CLI installed
cd Supabase
supabase start          # uses config.toml
supabase db reset       # applies migrations/ + seed.sql
```

For a hosted project, link and push migrations, or paste SQL from `Supabase/migrations/` into the SQL editor in order.

## Applying migrations

Migrations live in `Supabase/migrations/`:

| File | Purpose |
| --- | --- |
| `20260322000001_create_evidence_schema.sql` | Profiles, entries, tags, categories, check-ins, sessions, feedback, reminders |
| `20260322000002_enable_rls_policies.sql` | Row Level Security on all user-owned tables |
| `20260322000003_create_storage_bucket.sql` | Private `evidence-media` bucket + storage policies |

Apply in filename order. Seed data: `Supabase/seed.sql` (dev convenience; not required for the iOS client).

## Private storage bucket

Migration `20260322000003_create_storage_bucket.sql` creates:

- Bucket ID: **`evidence-media`** (private, not public)
- Path pattern: `<user_id>/<entry_id>/<asset_id>.<ext>`
- Allowed image MIME types; 50 MiB limit
- RLS so authenticated users only read/write objects under their own `user_id` folder

The iOS client uploads via `SupabaseMediaService` and never persists long-lived public URLs.

## Row Level Security (RLS)

Every user-owned table has RLS enabled with policies that restrict SELECT/INSERT/UPDATE/DELETE to `auth.uid() = user_id` (see migration `…_enable_rls_policies.sql`). Client-side filtering alone is not trusted. The service-role key must never ship in the app.

## Sign in with Apple

Implemented in `AuthenticationService` via Supabase `signInWithIdToken` (provider `.apple`).

**Manual steps still required in Apple / Supabase dashboards:**

1. Enable **Sign in with Apple** on the App ID (`com.evidence.app`) in the Apple Developer portal.
2. Confirm `Evidence/Evidence.entitlements` includes `com.apple.developer.applesignin` = `Default` (already in repo).
3. In Xcode → Signing & Capabilities, ensure Sign in with Apple appears for the Evidence target.
4. In Supabase Auth → Providers → Apple: configure Services ID, key, and team details per [Supabase Apple docs](https://supabase.com/docs/guides/auth/social-login/auth-apple).
5. Use a real device or simulator configuration that supports Apple ID sign-in testing.

## Email magic links

`signInWithMagicLink(email:)` calls Supabase OTP / magic-link email auth.

1. Enable Email provider in Supabase Auth.
2. Configure redirect URLs for the iOS app (custom URL scheme / universal link as you prefer for production).
3. For local Supabase, Inbucket captures emails (`config.toml` `[inbucket]`).

Magic link is the optional fallback; Sign in with Apple is preferred.

## Creating Config.xcconfig

```bash
cp Evidence/Configuration/Config.example.xcconfig \
   Evidence/Configuration/Config.xcconfig
```

Edit `Config.xcconfig`:

```
SUPABASE_URL = https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY = YOUR_SUPABASE_ANON_KEY
```

- `Config.xcconfig` is **gitignored**.
- `Evidence.xcconfig` optionally `#include?`s it and supplies empty defaults so local-only builds work without a config file.
- Build settings map `INFOPLIST_KEY_SUPABASE_URL` / `INFOPLIST_KEY_SUPABASE_ANON_KEY` into the generated Info.plist.
- `AppEnvironment` treats missing or placeholder values as empty and runs without cloud.

**Never commit service-role keys, Apple private keys, or real anon keys.**

## Running the app

1. Open `Evidence.xcodeproj`.
2. Scheme: **Evidence**.
3. Run on an iOS 18 simulator or device.
4. Without `Config.xcconfig`, onboarding, collection, check-ins, recommendations, local notifications, and app lock work offline.
5. With valid Supabase config + auth, enable cloud sync in Settings / onboarding.

Debug sample personal data can be seeded when `SampleData.enabled` is true (Debug + launch argument `-EvidenceSeedSampleData`). Release builds do not seed personal samples by default.

## Running tests

```bash
# On macOS with Xcode
xcodebuild test \
  -project Evidence.xcodeproj \
  -scheme Evidence \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or use Product → Test in Xcode.

Unit coverage currently includes recommendation scoring, safety-language detection, and sync-state helpers under `EvidenceTests/`. UI test target `EvidenceUITests` is wired; add UI flow tests as needed. **This Linux environment cannot execute these tests.**

## Local persistence

- SwiftData models under `Evidence/Models/Local/` (entries, tags, categories, check-ins, feedback, reminders, profile, …).
- Images are **not** stored in SwiftData; `LocalImageStorageService` writes UUID-named files under Application Support with file protection.
- Guided content (`GuidedContent.json`, 24 items) and safety copy (`SafetyContent.json`) are bundled locally for the MVP.

## Offline sync

`SyncCoordinator` is offline-first:

1. Save locally and mark `pendingUpload` / `pendingDeletion`.
2. UI updates immediately from SwiftData.
3. When authenticated + online, push deletions/uploads, then pull remote changes.
4. Retry with exponential backoff on failure; local collection remains usable.
5. Profile stores `lastSuccessfulSyncAt`.

Signing out does **not** delete local data. Cloud sync is optional (`cloudSyncEnabled` on the profile).

## Conflict handling

MVP resolution compares `updatedAt` timestamps. When a destructive overwrite is possible, sync preserves a local conflict copy and marks `syncStatus = .conflict`. Settings → Sync offers:

- Keep local (re-upload on next sync)
- Prefer cloud
- Keep both (duplicate)

**Limitation:** timestamp-based merge is not CRDT-quality; concurrent edits on two devices can still surprise users. Prefer resolving conflicts before continuing heavy editing.

## Image storage

- Import via PhotosPicker (no broad photo-library permission required for user-selected items).
- Local display/thumbnail generation via `LocalImageStorageService`.
- Remote path isolation: `<user_id>/…` validated before upload/delete.
- Accessibility description is stored separately from emotional meaning.
- Orphan cleanup is supported by the image storage service.

## Recommendation scoring

`RecommendationEngine` scores candidates deterministically (plus a small randomized tie-break among near-equal scores):

| Signal | Weight (approx.) |
| --- | --- |
| Exact support-need match | +6 |
| Exact emotion match | +5 |
| Previously helped (same emotion / need) | +3 |
| Favorite | +2 |
| Meaningful date in window | +2 |
| Matching strength | +1 |
| Shown in last 7 days | −4 |
| Not relevant in context | −7 |
| Do not use for this feeling | −10 |
| Made things harder | strong deprioritization |

Excludes archived, pending-deletion, `excludeFromCheckIns`, and untagged random images. Fallback chain: matching personal → broader personal → guided → neutral grounding. Numerical scores are never shown; a human-readable reason is.

## Notification behavior

- Local notifications only; authorization is **not** requested on first launch.
- User configures weekdays, time, frequency, categories, and preview privacy in Settings.
- Default preview mode: **generic** (“A reminder from your collection is ready.”).
- Title-only / full-content modes warn that content may be visible to others.
- Rescheduling replaces prior Evidence requests to avoid duplicates.
- Sensitive / excluded entries are not used for notifications unless explicitly allowed by settings.

## App-lock behavior

- Off by default; optional Face ID / Touch ID / device passcode via `LocalAuthentication`.
- Locks after ~30 seconds in background; privacy cover in the app switcher.
- Failed auth never deletes data.
- Info.plist key: `NSFaceIDUsageDescription` = *Evidence can lock your collection using Face ID so only you can open it.*

## Safety limitations

- Local, conservative phrase detection only (`LocalSafetyLanguageDetector`) for clear self-harm / harm-to-others / immediate danger language.
- Does **not** diagnose, confirm persecutory beliefs, or auto-contact anyone.
- Immediate-concern UI interrupts recommendations and points toward human support / emergency services; “I am safe right now” can continue to grounding.
- No hard-coded country-specific crisis hotlines in the MVP (localization strategy required first).
- Evidence is a wellness reflection tool, not clinical care.

## Accessibility checklist

Implemented toward WCAG 2.2 AA / strong native iOS a11y:

- [x] VoiceOver labels / traits on primary controls and cards
- [x] Dynamic Type via custom Evidence typography helpers
- [x] Image accessibility descriptions (`AccessibleImageView`)
- [x] Light and dark mode color sets
- [x] Semantic buttons and form controls
- [x] Accessible validation messaging in the entry editor
- [ ] Full VoiceOver pass of every screen on device (manual on macOS)
- [ ] Largest Dynamic Type audit of every layout (manual)
- [ ] Voice Control label sweep (manual)

Prefer verifying main flows (onboarding, check-in, collection, settings) with VoiceOver before release.

## Privacy model

Accurate claims (also shown in-app on the Privacy screen):

- Entries save locally first.
- Cloud sync is optional and requires sign-in.
- Synced rows are protected by Supabase RLS; media is in a private bucket.
- No advertising, no analytics SDKs, no private entry text sent to an AI service.
- Generic notification previews by default.
- App lock can hide the collection.
- Sign-out does not wipe local data.
- No clipboard monitoring, background photo scanning, contacts upload, microphone, or location permission in this MVP.

## Export and deletion

- **Export:** `ExportService` builds a JSON + images archive of local profile, entries, tags, categories, check-ins, feedback, reminders, and meaningful dates.
- **Delete entry / archive / restore:** collection UI + repositories.
- **Delete local data / cloud data / account:** `DataDeletionService` with explicit confirmation; reports partial failures instead of claiming success.
- Remote deletion is only reported successful when Supabase confirms it.

## Git workflow

Active branch for this cloud-agent delivery:

```
cursor/evidence-ios-mvp-13cb
```

That name follows Cursor cloud-agent branch conventions and is the working equivalent of `feature/evidence-ios-mvp` from the product spec.

```bash
git checkout cursor/evidence-ios-mvp-13cb
# … work …
git add -A && git commit -m "Describe change"
git push -u origin cursor/evidence-ios-mvp-13cb
```

Do not commit `Config.xcconfig`, user exports, DerivedData, or secrets (see `.gitignore`).

## Known limitations

- **Linux CI cannot `xcodebuild`** — compile and test on macOS / Xcode.
- App icon asset slot exists but may need a final 1024×1024 marketing icon.
- Sign in with Apple and magic-link redirects need live Apple Developer + Supabase dashboard configuration.
- Timestamp conflict resolution is best-effort for MVP.
- Trusted-contact calling UI exists in safety components but is not wired to a configured contact in the default safety flow (`trustedContactAvailable: false`).
- UI test suite target exists; coverage is still expanding.
- Universal Links / production email redirect URLs are environment-specific and not baked into the repo.

## Future roadmap (not implemented)

These are explicitly **out of scope** for this MVP:

- Audio entries
- Video entries
- iOS Share Extension
- OCR-assisted extraction
- User-confirmed AI tagging
- User-confirmed pattern analysis
- Home-screen widget with privacy controls
- Android app
- Direct Instagram or Pinterest import (after platform-policy and rights review)

## License / contact

Private project. Configure your own Supabase project and Apple Developer credentials before distributing builds.
