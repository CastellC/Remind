# Remind iOS — Milestone M0 Build Recovery Report

**Report date:** 2026-10-28 (Pacific/Honolulu)  
**Branch:** `fix/remind-m0-build-recovery`  
**Base:** `main` @ `5fd214c` (*Sync app branding and accent with Remind Figma updates*)  
**Repository:** `https://github.com/castellc/remind`

> **M0 is not complete.** This cloud agent host cannot run Xcode. Preparatory fixes were applied and documented; build, test, scheme listing via `xcodebuild`, simulator launch, and offline smoke verification remain **blocked** until a macOS + Xcode environment is available.

---

## 1. Environment and Xcode version

| Item | Result |
| --- | --- |
| Host OS | Linux `6.12.94+` (x86_64) — **not macOS** |
| `sw_vers` | Unavailable |
| Xcode / `xcodebuild` / `xcrun` / `swift` | **Not installed** (`command not found`) |
| `/Applications/Xcode*.app` | Absent |
| iOS Simulator | Unavailable |
| Cursor cloud environment | **None linked** (`environment: null`) |
| Self-hosted workers | **None connected** (0 personal / team-pool Mac workers) |
| SPM resolve | Not executed (requires Xcode toolchain) |

**Blocker (Task 1):** Per M0 instructions, when Xcode is unavailable the agent must stop and report rather than claim a successful build. No `xcodebuild` invocation was possible on this host.

**Required to finish M0:** A macOS machine with Xcode 16+ (project `LastUpgradeCheck = 1600`, `compatibilityVersion = Xcode 16.0`, deployment target iOS 18.0), either:

1. Local Xcode on a developer Mac, or  
2. A Cursor self-hosted worker (`agent worker start` after `agent login`) attached to this project.

---

## 2. Branch and commit

| Item | Value |
| --- | --- |
| Starting branch before M0 | `cursor/project-recovery-audit-9750` (audit-only; left intact) |
| M0 branch created | `fix/remind-m0-build-recovery` from `origin/main` |
| Working tree at start of M0 on `main` | Clean |
| Remote fetch | `git fetch origin --prune` (no merge performed) |
| PR #3 inspected | [Fix PhotosPicker MainActor isolation](https://github.com/CastellC/Remind/pull/3) — draft, `MERGEABLE`, head `cursor/fix-photospicker-sendable-6949` |
| PR #3 merge strategy | **Not merged blindly.** Diff reviewed; same minimal fix cherry-applied onto this branch |

Commit SHA for this report’s code changes will match the tip of `fix/remind-m0-build-recovery` after push (see git log on that branch).

---

## 3. Files changed

| Path | Change |
| --- | --- |
| `Evidence/Features/EntryEditor/EntryEditorView.swift` | PhotosPicker `@Sendable` label: capture `hasPickedImage` / `photoPickerTitle` on MainActor before the label closure (same fix as PR #3) |
| `Evidence.xcodeproj/project.pbxproj` | `INFOPLIST_KEY_CFBundleDisplayName` → `Remind`; Face ID usage string → Remind (Debug + Release). Bundle id remains `com.evidence.app`; target name remains `Evidence` |
| `Evidence.xcodeproj/xcshareddata/xcschemes/Evidence.xcscheme` | **New** shared scheme: app target + `EvidenceTests` + `EvidenceUITests` |
| `Evidence/Components/MeaningPromptView.swift` | User-facing “Evidence” → “Remind” |
| `Evidence/Features/Onboarding/OnboardingSteps.swift` | Onboarding use-case title brand → Remind |
| `Evidence/Features/Notifications/NotificationSettingsView.swift` | Denied-notifications copy → Remind |
| `Evidence/Services/NotificationService.swift` | Authorization-denied error string → Remind |
| `Evidence/Services/ExportService.swift` | Export README title → Remind |
| `M0_BUILD_RECOVERY_REPORT.md` | This report |

**Not changed (by design):** Supabase schemas/migrations/RLS, auth flows, `SyncCoordinator`, bundle identifier, Xcode target/product names, domain phrases such as “Evidence of capability”.

---

## 4. Build result

| Step | Status |
| --- | --- |
| Clean build (`xcodebuild clean build -scheme Evidence`) | **NOT RUN** — no Xcode |
| SPM dependency resolution | **NOT RUN** |
| Shared scheme visible to `xcodebuild -list` | **NOT CONFIRMED** on this host; scheme file committed under `xcshareddata/xcschemes` for Mac verification |

Known compile issue addressed in source (pending Mac confirmation): PhotosPicker MainActor isolation in `EntryEditorView`.

---

## 5. Unit test results

**NOT EXECUTED.** No simulator / XCTest host available.

Expected Mac command once Xcode is available:

```bash
xcodebuild test \
  -project Evidence.xcodeproj \
  -scheme Evidence \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' \
  -only-testing:EvidenceTests
```

(Adjust simulator name/OS to an installed iOS 18+ runtime.)

---

## 6. UI test results

**NOT EXECUTED.**

UI scaffolding lives in `EvidenceUITests`. Mac verification should use the shared `Evidence` scheme’s `EvidenceUITests` testable. Do not treat scaffolding as a green suite until it actually runs.

---

## 7. Offline smoke-test results

**NOT EXECUTED** (no simulator launch).

Manual checklist for Mac verification (no Supabase credentials / empty `Config.xcconfig`):

1. App launches without crash  
2. Onboarding appears when appropriate  
3. User can reach **Today**  
4. Tab / navigation works  
5. Create a text evidence entry; confirm local persist  
6. Force-quit and relaunch; entry still present  

Code review note (not a runtime proof): `AppEnvironment` / unavailable remotes and in-memory fallback in `EvidenceApp` are designed for offline-first launch without Supabase credentials.

---

## 8. Remaining blockers

1. **Hard blocker:** No macOS + Xcode on the agent host; no self-hosted Mac workers connected.  
2. **Unverified:** Clean build, unit tests, UI tests, `xcodebuild -list` scheme visibility, offline smoke.  
3. **Signing:** `DEVELOPMENT_TEAM` is empty — simulator builds usually OK; device installs need a team.  
4. **SPM:** No committed `Package.resolved` (gitignored) — first Mac resolve must succeed against network for `supabase-swift`.  
5. **PR #3:** Still open as draft; this branch carries the equivalent fix — close or supersede #3 after Mac-confirmed green build to avoid duplicate work.  
6. **M0 acceptance:** Not met until a Mac run proves build + tests + launch + local persistence.

---

## 9. Recommended next milestone

**Immediate (still M0):** Re-run this branch on a Mac with Xcode 16+ / iOS 18+ simulator:

1. Open `Evidence.xcodeproj`, resolve packages.  
2. `xcodebuild -list` → confirm shared `Evidence` scheme.  
3. Clean build + `EvidenceTests` (+ UI tests if stable).  
4. Offline smoke checklist above.  
5. Update this report with exact pass/fail output and commit SHA.

**After green M0 → M1 candidates** (from recovery audit; out of scope here):

- Complete auth URL scheme / account-deletion RPC alignment only if product-required  
- Expand sync beyond entries-only if product-required  
- CI macOS workflow using the shared scheme  

Do **not** rebuild the app or change Supabase schemas as part of finishing M0.
