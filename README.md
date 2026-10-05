# AI Remote — MVP v0.1

AI Remote is a voice-first Flutter phone application designed around a simple remote-control metaphor:

```text
PREVIOUS  ⏮   select previous channel
PLAY      ▶   activate / hold to talk
NEXT      ⏭   select next channel
STOP      ■   finish or cancel the current interaction
```

The phone owns microphone capture, conversation state, AI access, translation, speech playback, and audio routing. Watches and future hardware remain thin generic remotes.

## Current milestone

Milestone 1 is implemented in **mock voice mode**:

- Three ordered channels: General Chat, Translator, and Technical Agent.
- Persistent selected channel using `shared_preferences`.
- Independent `ConversationSession` history for every channel.
- Explicit state machine: `IDLE`, `CHANNEL_SELECTED`, `LISTENING`, `PROCESSING`, `AI_SPEAKING`, `TRANSLATING`, `ERROR`, and `DISCONNECTED`.
- Previous, play/push-to-talk, next, stop, and translation-direction controls.
- Real microphone permission and audio capture through the `record` package.
- Mock transcription/reply or translation, followed by spoken device TTS output.
- Generic `RemoteCommand` and `RemoteController` boundaries for future hardware.
- Android MediaSession adapter for Amazfit Bip U Pro, headsets, car controls,
  and other compatible Bluetooth media remotes.
- Android `AudioPlaybackCapture` bridge for analyzing audio currently played by
  Spotify or another compatible media app, with a local live chord baseline.
- Authenticated session backend for future OpenAI Realtime client secrets.

Mock mode intentionally does **not** transcribe the captured audio. It generates a clearly simulated transcript and response so navigation, state, persistence, context isolation, microphone capture, and spoken-output flow can be tested without credentials.

## Architecture

```text
Watch / earbud / button / car
              │
        RemoteAdapter
              │
        RemoteCommand
              │
        AppController
         ├── ChannelManager ── ConversationSession per channel
         ├── AiRemoteStateMachine
         ├── VoiceEngine ───── Mock now / Realtime WebRTC later
         ├── TranslatorService
         ├── AudioCaptureService
         ├── ChordMonitor ── Android AudioPlaybackCapture → local analyzer
         └── SpeechOutput ──── system-selected phone/Bluetooth route
```

Key source areas:

- `lib/core`: application controller, domain models, and state machine.
- `lib/channels`: ordered channel selection and isolated contexts.
- `lib/voice`: capture, output, mock engine, audio-route and backend-session boundaries.
- `lib/translator`: replaceable translator service and mock turn mode.
- `lib/remote`: generic command routing and device adapter contracts.
- `lib/music`: system-playback capture, chord estimates and replaceable
  real-time chord analysis.
- `lib/ui`: phone interface.
- `backend`: secure Realtime session backend.

No watch manufacturer appears in business logic.

## Requirements

- Flutter stable with Dart compatible with `pubspec.yaml`.
- Android SDK and an emulator or physical Android phone.
- Node.js 20 or newer only when testing or running the optional backend.

## Run the phone app

```powershell
flutter pub get
flutter run
```

On this workstation the explicit Flutter path is:

```powershell
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat run
```

Grant microphone access when Android requests it. Tap the center button to activate a channel. Hold it to record and release it to complete the mock turn. Android routes TTS through the active system output, which can be the phone speaker, Bluetooth earbuds, or another selected audio device.

## Test mock mode

No backend or `.env` file is required.

## Live chord monitor from Spotify or other apps

On Android 10+, press the **LIVE CHORD MONITOR** play button in AI Remote.
Android shows a system consent dialog for capturing playback audio. After
approval, the phone receives PCM audio from compatible media apps and analyzes
it locally. The current baseline recognizes major/minor triads, suspended
chords and common seventh chords (`7`, `m7`, `maj7`), then exposes the latest
estimate to the phone UI and the generic media-session display used by the Bip
U Pro.
The analyzer uses a Hann window and exact pitch frequencies to reduce note
leakage. A clear new chord is shown on its first analysis window; ambiguous
alternatives are held back to reduce flicker. This is still an experimental
local estimator, not a measured accuracy guarantee.

The Android implementation keeps capture alive through a dedicated
`mediaProjection` foreground service, so analysis can continue when the screen
is locked. Android 14+ requires this service type and its matching permission.

The source app must allow Android playback capture. Some apps can disable it
for privacy, DRM, or their own audio policy, so support is app- and device-
dependent. The first test target is Spotify on the physical Android phone.
Stopping AI Remote or revoking the Android projection permission stops capture.
The monitor is intentionally separate from microphone push-to-talk and does
not upload the song audio to the backend.

While the monitor is running it takes over the phone screen and media controls.
The selected AI channel is preserved: **Previous** lowers the analysis level,
**Next** raises it, and **Pause/Stop** ends the monitor. Ten levels range from
about 1000 ms to 170 ms between analyses, with the level displayed on the phone
and next to the chord in the media title sent to compatible watches. The phone
shows the current chord at large size and hides AI channel activity.

```powershell
C:\src\flutter\bin\dart.bat format .
C:\src\flutter\bin\flutter.bat analyze
C:\src\flutter\bin\flutter.bat test
```

The tests cover channel ordering and persistence, context isolation, valid and invalid state transitions, generic remote-command routing, chat/agent mock push-to-talk, translator direction, target speech language, and phone UI navigation.

Backend tests have no external API calls:

```powershell
Set-Location backend
npm test
```

## Backend and environment variables

Copy `.env.example` to an ignored local environment file or inject the variables through the deployment platform. The standard OpenAI key is server-side only.

### Optional Codex App Server bridge

AI Remote can route a selected channel to a persistent Codex App Server thread through
`POST /v1/codex/turn`. The bridge is disabled by default. When enabled, the backend
starts `codex app-server` over stdio, keeps the ChatGPT OAuth access token in the
backend environment, and never sends it to Flutter. Configure `CODEX_ACCESS_TOKEN`,
`CODEX_WORKSPACE_ROOT`, and `CODEX_APP_SERVER_ENABLED=true` only on a trusted host.
The first live request must be tested on that host; a local APK cannot access the
App Server directly.

To route selected phone channels to Codex, build with the public configuration
`--dart-define=AI_REMOTE_CODEX_CHANNELS=lavormetal-daily,technical-agent`.
This contains channel ids only, not credentials. Those channels still require the
normal AI Remote bearer authentication, and fall back to the existing OpenAI/mock
path when Codex is not enabled on the backend.

Required for live API calls:

- `OPENAI_API_KEY`: standard server credential; never put it in Flutter.
- `AI_REMOTE_AUTH_MODE=pairing`: personal non-Google authentication mode.
- `AI_REMOTE_PAIRING_CODE`: server-side one-time pairing code; never put it in Flutter builds.
- `AI_REMOTE_SESSION_SECRET`: server-side signing secret for short-lived pairing sessions.
- `OIDC_AUDIENCE`: the public Google Web OAuth client ID. Google issuer and JWKS defaults are preconfigured; they can be overridden with `OIDC_ISSUER` and `OIDC_JWKS_URL`.
- `GOOGLE_ALLOWED_EMAIL` (or `GOOGLE_ALLOWED_SUBJECT`): restricts the private backend to the owner's verified Google account.
- A reachable HTTPS backend URL and the same public client ID supplied to Flutter at build time.

Optional:

- `OPENAI_REALTIME_MODEL` (example default: `gpt-realtime-2.1`).
- `OPENAI_REALTIME_VOICE` (example default: `marin`).
- `OPENAI_TRANSLATION_MODEL` (example default: `gpt-realtime-translate`).
- `OPENAI_TRANSCRIPTION_MODEL` (bounded push-to-talk recordings; default `gpt-transcribe`).
- `OPENAI_RESPONSES_MODEL` (text answer generation; configurable for the project/account).
- `HOST` and `PORT`.
- `ALLOW_INSECURE_DEV_AUTH=true` only for loopback development. It is rejected for non-loopback clients.

Run after setting environment variables:

```powershell
Set-Location backend
npm start
```

For the local key created by the secure Codex setup flow, use the dedicated
development command from the backend directory. It loads the ignored
`../.env.local` file and keeps `OPENAI_API_KEY` server-side:

```powershell
Set-Location backend
npm run start:local
```

This local command still requires the Google Web OAuth client ID for API
requests. `ALLOW_INSECURE_DEV_AUTH=true` is intended only for loopback testing.

Endpoints:

- `GET /health`
- `POST /v1/realtime/client-secret`
- `POST /v1/realtime/translation-client-secret`
- `POST /v1/voice/turn` (authenticated, bounded push-to-talk WAV + per-channel history)

In pairing mode, `POST /v1/auth/pair` exchanges the server-side pairing code
for a seven-day signed bearer session. AI endpoints require that bearer token;
the pairing code and session secret never leave the backend. Google OIDC
remains an optional alternative provider. In both modes the backend hashes the
authenticated subject into a privacy-preserving safety identifier and never
sends `OPENAI_API_KEY` to the phone.

## Personal pairing setup (recommended, non-Google)

Set `AI_REMOTE_AUTH_MODE=pairing`, `AI_REMOTE_PAIRING_CODE` and
`AI_REMOTE_SESSION_SECRET` only in the backend environment. Use long random
values and keep them out of Flutter, `--dart-define`, logs and APKs. The app is
built with only the public HTTPS URL:

```powershell
.\tool\build_pairing.ps1
```

On first use, tap **COLLEGA AI REMOTE** and enter the pairing code. The phone
exchanges it over HTTPS and stores only the seven-day session token in platform
secure storage. If the backend is unavailable, the app remains in mock mode.

The non-Google public path uses the named Cloudflare Tunnel described in
`cloudflared/config.yml`. The tunnel credential JSON stays under the user's
`.cloudflared` directory and is never committed. Run the backend with the
pairing variables loaded, then run `cloudflared tunnel --config
cloudflared/config.yml run ai-remote` as a supervised service; `/health` is
public, while all AI endpoints require the pairing bearer token.

## Google sign-in setup (optional legacy alternative)

Google sign-in is optional and is not part of the product concept. The app
now depends on the provider-neutral `AiIdentityService` contract, so a future
"Continue with ChatGPT" flow can replace Google without changing channel,
remote, voice, or audio-routing code. Do not create Google OAuth credentials
unless you explicitly choose Google as the identity provider.

Google account access on the phone is not enough by itself: Google requires an
OAuth client registration for AI Remote. Register Android package
`com.airemote.ai_remote` and its signing SHA-1 fingerprint, then create a Web
application OAuth client. The Web client ID is public configuration, not a
password or client secret. Google recommends sending the signed ID token to the
backend over HTTPS and verifying it server-side; the backend checks its
signature and claims.

Set the Web client ID as `OIDC_AUDIENCE` in the backend environment, set
`GOOGLE_ALLOWED_EMAIL` to the Google account that owns this app, and use the
same Web client ID to build the phone app along with the HTTPS backend URL:

The repository also contains `tool/build_live.ps1`, which fixes the backend
URL to `https://remote.aquariusageai.com` and accepts only the public Google
Web client ID. It never accepts or passes `OPENAI_API_KEY` to Flutter. The
script must not be run until the backend URL, OIDC audience, and owner
allowlist are actually deployed and verified.

```powershell
C:\src\flutter\bin\flutter.bat build apk `
  --dart-define=AI_REMOTE_BACKEND_URL=<https-backend-url>
```

After this configuration, the app offers “Collega con Google”; successful
sign-in swaps the mock voice engine for the OpenAI push-to-talk engine. Without
the two build values, the app intentionally remains in mock mode. The OpenAI
key is never a Flutter build argument.

## OpenAI push-to-talk implementation

The API voice path is now implemented as a backend-mediated request: the phone
captures mono 24 kHz PCM, wraps it as WAV, and sends it with the selected
channel's own conversation history to the authenticated backend. The backend
transcribes the completed recording with the Audio Transcriptions API and sends
the transcript plus only that channel's history to the Responses API. It
returns transcript and answer text; Android speaks the answer through the
existing system TTS/audio route. The OpenAI key never leaves the backend, and
Responses storage is disabled for these requests. This bounded recording flow
is the low-latency push-to-talk baseline, not continuous realtime voice. The
default fast path uses `gpt-4o-mini-transcribe` plus `gpt-4.1-mini`; the Realtime
2.1 client-secret route is kept for the next streaming transport milestone.

`OpenAiPushToTalkVoiceEngine` is injectable and supports cancellation. The
factory deliberately selects `MockVoiceEngine` until Google sign-in settings
and a reachable HTTPS backend URL are configured for the phone.
The local `.env.local` currently has the OpenAI key but no OIDC issuer,
audience, or JWKS configuration; consequently API calls from the installed
phone are not yet enabled. Do not expose the backend with loopback-development
authentication to make the phone reach it. Once the Google Web OAuth client
and HTTPS backend are configured, the app sends Google's short-lived signed ID
token; no client-side OpenAI credential or static API key is needed.

The API path follows OpenAI's current [speech-to-text guide](https://developers.openai.com/api/docs/guides/speech-to-text)
for completed recordings and the [text generation guide](https://developers.openai.com/api/docs/guides/text)
for the Responses API. The Realtime interfaces remain separately available for
the future continuous mode.

## Realtime voice design

### Live chord detection boundary

The live monitor is a local DSP baseline, not the same model used by
Chordify or Chord AI. Those products combine spectrogram/chroma features with
beat tracking and a temporal model; frame-by-frame template matching alone is
less reliable on vocals, dense arrangements and bass-heavy mixes. AI Remote
confirms a new chord across multiple analysis windows to suppress one-frame
jumps, and refreshes the phone/watch media metadata on each accepted change.
The next accuracy milestone should replace this baseline with an on-device ML
model or an equivalent beat-synchronous backend rather than adding ad-hoc
templates.

The secure boundary follows the current official OpenAI flow: a mobile client should use WebRTC for a Realtime session and obtain a short-lived credential from a trusted backend. Translation uses its dedicated Realtime translation session. See the official [WebRTC guide](https://developers.openai.com/api/docs/guides/voice-webrtc) and [Realtime translation guide](https://developers.openai.com/api/docs/guides/realtime-translation).

### Optional Cloud Run packaging

The backend includes `backend/Dockerfile` and listens on `0.0.0.0` when no
`HOST` is supplied, which is required by container platforms. The Dockerfile
does not copy `.env` files or tests. Deployment still requires an explicitly
chosen Google Cloud project, a Secret Manager value for `OPENAI_API_KEY`, the
OIDC configuration, and an HTTPS URL; no deployment is performed by local
builds. Keep `HOST=127.0.0.1` in `.env.local` for loopback development.

`tool/deploy_cloud_run.ps1` contains the guarded deployment command for the
planned project `ai-remote-510509`. It requires the Google Cloud CLI login, an
existing Secret Manager secret name, the public OIDC Web client ID, and the
allowlisted owner email. It never accepts the OpenAI key value. The optional
`-CreateDomainMapping` switch creates the Cloud Run mapping but still requires
the DNS target returned by Google to be entered at the DNS provider.

`BackendRealtimeSessionGateway` is implemented in Flutter and the backend
session endpoints are ready. The native Flutter WebRTC audio transport remains
the next live-voice increment; the active voice MVP remains the fully
testable mock engine.

For continuous mode, the existing interfaces are intended to gain:

- streaming microphone and model audio;
- server or semantic voice-activity detection;
- natural turn detection and barge-in;
- reconnect and session recovery;
- mute, stop, and explicit audio-route controls.

Push-to-talk stays available as the reliable fallback.

## Wear OS milestone

The next hardware milestone adds a companion that:

1. Connects to the phone through a Wear OS adapter.
2. Displays the current channel, connection, and listening state.
3. Emits only generic `PREVIOUS`, `PLAY`, `NEXT`, and `STOP` commands.
4. Provides haptic feedback on channel changes.
5. Leaves AI, translation, audio, and conversation history on the phone/backend.

The same app core can later accept Bluetooth buttons, headsets, steering-wheel controls, smart glasses, or other devices by adding adapters rather than changing channel or voice logic.

## Amazfit Bip U Pro setup

The Bip U Pro runs RTOS rather than Wear OS or a programmable Zepp OS target,
so AI Remote uses its built-in **Music** controller instead of installing AI
logic on the watch.

1. Pair the Bip U Pro normally in the Zepp app and keep Bluetooth enabled.
2. In Zepp, open the Bip U Pro app settings and enable the notification/status
   access requested for Android music control.
3. Keep Zepp allowed to run in the background.
4. Open AI Remote once and complete one phone push-to-talk turn so Android can
   request and save microphone permission.
5. Open **Music** from the watch app list or shortcut cards.
6. The watch should show the selected AI Remote channel as the current track.

Control mapping:

```text
Watch Previous  → previous AI channel
Watch Play      → start push-to-talk capture
Watch Pause     → finish the turn and send it
Watch Next      → next AI channel
Watch volume    → Android system media volume
```

This adapter is deliberately manufacturer-independent: it publishes an Android
media session and receives standard media-button events. The same path can work
with earbuds, Bluetooth buttons and vehicle controls. Exact metadata display and
background behavior still depend on Android, Zepp notification access and device
firmware, and must be verified on the physical phone/watch pair. The in-app
`MEDIA READY` badge confirms that Android's media adapter is active; it does not
claim that a particular watch is currently connected.

## Security notes

- `.env`, `.env.local`, and backend equivalents are ignored by Git.
- No permanent provider credential is accepted by the Flutter gateway.
- Production session routes fail closed when OIDC is not configured.
- The backend allowlists channel instructions instead of accepting arbitrary client prompts.
- Store signing, deployment, and live device verification are not part of Milestone 1.
- During Live Chord Monitor the Android phone requests `KEEP_SCREEN_ON`.
  The Bip U Pro display timeout remains controlled by Zepp firmware and cannot
  be overridden through the generic Bluetooth media-session protocol.
