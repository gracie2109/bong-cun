# apps/mobile

Capacitor shell for the customer app (Android first). It holds no screens: the UI is `apps/web`, built
with the `mobile` target (SPA, no admin) and copied into `android/` by `cap sync`.
Plan: [docs/ke-hoach-app-mobile.md](../../docs/ke-hoach-app-mobile.md).

## Build

```bash
SUPABASE_URL=... SUPABASE_KEY=... npm run mobile:apk   # from the repo root
```

That runs, in order: `generate:mobile` (apps/web → `.output/public`), `cap sync android`,
`./gradlew assembleDebug`. The APK lands in `android/app/build/outputs/apk/debug/app-debug.apk`.
Needs JDK 21 and the Android SDK (`ANDROID_HOME`). CI builds it for you: see the "Mobile Android" workflow.

`SUPABASE_URL` / `SUPABASE_KEY` are the public anon values already set on Vercel.

## Rules

- **Plugin versions.** A `@capacitor/*` plugin used by `apps/web` must also be listed here with the same
  range (`cap sync` reads this file; npm installs one copy at the root). `npm run check:versions` checks it.
- **Native code only in `apps/web/src/features/native`.** dependency-cruiser fails on `@capacitor/*` imports elsewhere.
- **Icon and splash** come from `assets/`: replace `icon-only.png`, `icon-foreground.png`, `icon-background.png`,
  `splash.png`, `splash-dark.png` and run `npm run assets -w @bongcun/mobile`. The current ones are a placeholder
  ("BC" on orange).
- `android/` is committed; build output, `local.properties` and the copied web bundle are ignored.
