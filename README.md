# AI Remote — phone-first Codex and voice controller

AI Remote is a Flutter phone app that treats chats and tools as selectable channels. The phone owns the interface, audio capture, local conversation database, and remote commands; watches and other controls remain generic media remotes.

```text
PREVIOUS  select previous channel
PLAY      activate / hold to talk
NEXT      select next channel
STOP      finish or cancel the current interaction
```

## Current capabilities

- General Chat and Translator channels, plus independently named AI channels.
- Codex Developer channel for sending a typed or push-to-talk task to the existing local Codex App Server.
- An explicit, one-use, 60-second phone confirmation is required before each Codex task. The watch cannot authorize a task by itself.
- Per-channel conversation history and Codex thread references persist in the phone's private SQLite database; selected channel persists separately.
- Mock voice mode remains available without a backend. Mock replies are visibly simulated and are not proof of a live model response.
- Authenticated backend routes for chat, voice, pairing, and optional Codex routing.
- Generic media-button controls for compatible watches, headsets, and car controls.

## Architecture

```text
Watch / headset / car → Android media adapter → RemoteCommand → AppController
                                                       ├─ ChannelManager → ConversationStore (SQLite)
                                                       ├─ VoiceEngine / TranslatorService
                                                       └─ authenticated backend → OpenAI or local Codex App Server
```

The phone does not run Codex. In Codex Developer mode, the trusted backend launches the already-installed Codex CLI/App Server on the configured computer and workspace. The bridge is not an arbitrary RPC proxy: it uses the channel allowlist and authenticated AI Remote routes. No watch-specific behavior is part of business logic.

Key source areas: `lib/core` (controller and state machine), `lib/channels`, `lib/services` (conversation storage), `lib/voice`, `lib/translator`, `lib/remote`, `lib/ui`, and `backend/src`.

## Requirements and local run

- Flutter stable and Android SDK for the phone app.
- Node.js 20+ for backend tests or server.
- A Codex CLI installation and existing local Codex login only for the optional Codex bridge.

```powershell
Set-Location D:\Codex\ai_remote
flutter pub get
flutter run
```

Mock mode is the fallback and can be used to exercise navigation and simulated turns without credentials or a live backend. For local checks:

```powershell
dart format lib test
flutter analyze
flutter test
Set-Location backend
node --test
```

On this workstation Flutter may be invoked as `C:\src\flutter\bin\flutter.bat` and Node as `C:\Users\simon\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe` if those tools are not on PATH.

## Conversation storage

The app stores messages and each channel's Codex thread reference in its private `ai_remote.db` SQLite database. Histories are isolated by channel and restored after restart. Deleting a custom chat removes its local messages and thread reference. Conversation content is not currently uploaded to a website or gestionale. Clearing app data or uninstalling can remove the database.

`ConversationStore` is the persistence boundary. A future web/gestionale integration must use a separate authenticated sync/export service, explicit consent, data minimization, and an auditable mapping of approved fields. The local SQLite database is not a cloud backup.

## Backend configuration and security

Copy `.env.example` to an ignored local environment file or configure variables in the trusted backend environment. Never place secrets in Flutter source, APKs, or `--dart-define` values.

Required for authenticated provider calls:

- `OPENAI_API_KEY`: server-side only.
- `AI_REMOTE_AUTH_MODE` and pairing settings or the configured identity-provider audience and allowlist.
- `AI_REMOTE_SESSION_SECRET` and the other authentication variables documented in `.env.example`.
- `HOST`, `PORT`, and a reachable HTTPS backend for phone access.

`GET /health` is a health check. AI routes require backend authentication. Pairing exchanges a server-only pairing code for a short-lived bearer session. Never put the pairing code, signing secret, Codex login, or OpenAI key in a mobile build.

### Optional Codex App Server bridge

The bridge is disabled unless configured on the trusted host. Set `CODEX_APP_SERVER_ENABLED=true`, `CODEX_WORKSPACE_ROOT` to the intended checkout, and `AI_REMOTE_CODEX_CHANNELS` to a comma-separated allowlist of channel IDs. `tool/build_pairing.ps1` includes the public channel setting `codex-developer` by default; channel IDs are not credentials. The local launcher resolves the installed Codex executable and scopes the workspace to `D:\Codex\ai_remote`.

The public-tunnel launcher forces pairing authentication, disables loopback-only development auth, and binds to `127.0.0.1:8787` so Cloudflare is the only public ingress. Pairing-code failures are rate-limited by the client address.

The App Server is started over stdio with `workspace-write` sandbox and `on-request` approval policy. AI Remote currently gates each user task with a separate explicit confirmation on the phone. If App Server asks for a lower-level file/command approval that the phone UI cannot yet represent, the request must fail closed rather than being silently approved. Diff review UI, progress streaming, and forwarding those runtime approval prompts remain future work.

Typed Codex tasks and voice tasks both require the one-turn confirmation. Confirmation expires after 60 seconds and is consumed by one task. On the watch, authorize the next task on the phone first, then use PLAY. Text uses the user's existing local Codex CLI login. Voice transcription additionally needs the server-side OpenAI key; no key is sent to Flutter.

### Text and voice routes

`POST /v1/chat/turn` sends an authenticated, allowlisted text turn to the configured provider. `POST /v1/voice/turn` handles bounded push-to-talk audio, with the OpenAI credential remaining on the backend. Translator turns use the selected language direction through the translator service. The OpenAI Responses request does not store responses. The mock engine is always the offline fallback where configured; mock output is not live-provider evidence.

The local push-to-talk flow captures a completed recording, sends it to the authenticated server, then speaks the response through Android's selected audio route. This is not continuous realtime voice. Continuous streaming, natural turn detection, interruption, reconnect recovery, and surfaced App Server approvals remain separate future milestones.

### LumenSystem channel (read-only MVP)

The `LumenSystem` channel can answer questions using activities from today through the next 30 days. The trusted AI Remote backend calls only Lumen's dedicated `GET /api/v1/integrations/ai-remote/activities` route. The Lumen endpoint caps results at 50 and returns a reduced activity shape; it does not expose write operations. Lumen notes are treated as untrusted reference data and the assistant must not claim to have changed records.

Configure `LUMEN_SYSTEM_BASE_URL` and `LUMEN_AI_REMOTE_READ_TOKEN` on the AI Remote backend. Configure the same dedicated token as `LUMEN_AI_REMOTE_READ_TOKEN` in Lumen's server environment. Never reuse `LUMEN_API_TOKEN` and never put either token in Flutter, an APK, or a `--dart-define`. Loopback HTTP is acceptable only when both server processes run on the same PC; a remote Lumen host requires HTTPS. Without this server configuration the channel fails closed with a clear service error. No data is read from or copied directly between the two SQLite databases.

## Build configuration

For a personal paired build, configure the backend first and then run:

```powershell
.\tool\build_pairing.ps1
```

The app build may contain the public HTTPS backend URL and Codex channel IDs, but never API keys, pairing codes, session secrets, or local Codex credentials. Keep mock mode as the fallback when the backend or authentication is unavailable. A build does not imply installation, backend availability, or a live successful provider turn.

## Generic watch controls

The Amazfit Bip U Pro uses its built-in Music controller; it does not run AI Remote code. Android publishes a media session and maps standard media buttons to PREVIOUS, PLAY, NEXT, and STOP. Device metadata and background delivery depend on Android, Zepp permissions, Bluetooth state, and firmware, and must be verified on the physical pair. The watch is not the AI/audio engine.

## Live chord monitor (experimental)

Android playback capture can analyze compatible music apps locally after system consent. This experimental DSP baseline is not equivalent to Chordify or a trained transcription model and has no accuracy guarantee. DRM/privacy policy can block capture. It is separate from AI chat and does not upload captured music. The phone may keep its screen on while the monitor runs; watch display timeout remains controlled by its firmware.

## Status and limitations

Source and tests do not prove that the public backend is online, that an APK is installed on the phone, or that a real Codex/OpenAI turn succeeded. Verify backend health, authentication, provider response, and physical watch behavior separately. No deployment or GitHub push is implied by a local code change.
