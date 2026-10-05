---
name: ai-remote-voice-pipeline
description: Build, diagnose, or extend AI Remote voice and translation flows, including push-to-talk, audio capture, speech output, mock providers, and future realtime providers. Use when work concerns microphone input, transcription, translation, synthesized speech, interruptions, or live voice sessions.
---

# AI Remote Voice Pipeline

Treat push-to-talk as the stable baseline and realtime voice as an additive provider.

## Flow to preserve

Trace changes across `AudioCaptureService`, `VoiceEngine` or `TranslatorService`, `SpeechOutput`, `AppController`, and `AiRemoteStateMachine`. Preserve the lifecycle:

`channelSelected -> listening -> processing -> translating? -> aiSpeaking -> channelSelected`

Invalid or failed operations must enter a recoverable error state with a user-facing message. Cancellation must stop capture, provider work, translation, and speech output without allowing a stale result to update another channel.

## Provider boundary

- Keep `MockVoiceEngine` and `MockTranslatorService` runnable without network access.
- Put live services behind the existing interfaces or a deliberate compatible extension.
- Send only the selected channel instructions and that channel's history.
- Make continuous-mode capability explicit; do not assume every provider supports it.
- For OpenAI Realtime or API work, verify the current official OpenAI documentation before choosing endpoints, events, models, authentication, or session semantics.
- Never place a long-lived API key in Flutter. Use a trusted backend and, when officially supported for the chosen flow, backend-issued short-lived client credentials.

## Verification

Test normal turns, translation direction, cancellation, permission denial, provider failure, rapid channel changes, and stale async completions. Run formatter, analyzer, and the full Flutter test suite. State separately whether microphone, TTS, network, and device behavior were tested on hardware.
