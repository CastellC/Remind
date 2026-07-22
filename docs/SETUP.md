# Evidence setup

Condensed steps to run the iOS app with optional Supabase sync. Full product docs: [README.md](../README.md).

## 1. Xcode project

- macOS + **Xcode 16+**
- Open `Evidence.xcodeproj`
- Scheme **Evidence**, iOS **18.0+** simulator or device
- Signing: Automatic — select your Team (project leaves `DEVELOPMENT_TEAM` empty)
- Regenerate project if needed: `python3 scripts/generate_xcode_project.py`

Local-only use works with no backend. Continue for cloud sync.

## 2. Config.xcconfig

```bash
cp Evidence/Configuration/Config.example.xcconfig \
   Evidence/Configuration/Config.xcconfig
```

Set:

```
SUPABASE_URL = https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY = YOUR_ANON_KEY
```

`Config.xcconfig` is gitignored. `Evidence.xcconfig` `#include?`s it and injects `SUPABASE_URL` / `SUPABASE_ANON_KEY` into the generated Info.plist. Never put the **service-role** key in the client.

## 3. Supabase

1. Create a Supabase project; copy URL + **anon** key into `Config.xcconfig`.
2. Apply migrations in order from `Supabase/migrations/`:
   - `20260322000001_create_evidence_schema.sql`
   - `20260322000002_enable_rls_policies.sql`
   - `20260322000003_create_storage_bucket.sql` (private bucket `evidence-media`)
3. Optional seed: `Supabase/seed.sql`.

CLI alternative (local):

```bash
cd Supabase
supabase start
supabase db reset
```

Hosted: `supabase link` + `supabase db push`, or run the SQL files in the dashboard SQL editor.

Confirm:

- RLS enabled on user-owned tables
- Bucket `evidence-media` is **private**
- Object paths use `<user_id>/…`

## 4. Sign in with Apple

1. Apple Developer → App ID `com.evidence.app` → enable **Sign in with Apple**.
2. Xcode target **Evidence** → Signing & Capabilities → Sign in with Apple (entitlements file already sets `com.apple.developer.applesignin` = Default).
3. Supabase → Authentication → Providers → **Apple** — configure per [Supabase Apple guide](https://supabase.com/docs/guides/auth/social-login/auth-apple).

## 5. Email magic links

1. Supabase → Authentication → Providers → **Email** enabled.
2. Set redirect URLs appropriate for your build (simulator/local vs production).
3. Local stack: check Inbucket for messages (`Supabase/config.toml` `[inbucket]`).

## 6. Run

1. Clean build folder if you just added `Config.xcconfig`.
2. Run **Evidence** (⌘R).
3. Complete onboarding (skippable) or use Today / Collection offline.
4. Sign in from Settings or onboarding to enable cloud sync.

## 7. Tests (macOS only)

```bash
xcodebuild test \
  -project Evidence.xcodeproj \
  -scheme Evidence \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Linux environments cannot run `xcodebuild`.

## Checklist

- [ ] Xcode 16 opens `Evidence.xcodeproj` and resolves the Supabase package
- [ ] Team selected for code signing
- [ ] `Config.xcconfig` present only on your machine (if using cloud)
- [ ] Migrations + RLS + `evidence-media` applied
- [ ] Apple provider configured (if testing Sign in with Apple)
- [ ] Email provider configured (if testing magic links)
- [ ] Face ID usage string present (generated Info.plist via build setting)
