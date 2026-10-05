# AI Remote project instructions

These instructions apply to the entire repository.

## Product contract

AI Remote is a Flutter/Dart, voice-first controller. The phone owns the AI session and the wearable or external device remains a hardware-independent remote. Preserve these invariants:

- Keep the explicit lifecycle in `AiRemoteStateMachine`; do not replace it with scattered booleans.
- Keep conversation history isolated per channel through `ChannelManager` and `ConversationSession`.
- Keep device input generic through `RemoteCommand` (`previous`, `play`, `next`, `stop`). Put platform- or vendor-specific behavior behind `RemoteAdapter`/`RemoteController`.
- Keep voice, translation, audio capture, speech output, persistence, and device integrations behind interfaces so mocks remain usable.
- Keep push-to-talk as the reliable baseline. Continuous or realtime voice must be additive and must not break the mock flow.
- Never embed an OpenAI API key or another long-lived secret in the Flutter client. Use a trusted backend and short-lived credentials where the selected API supports them.
- Treat actions that affect the device, accounts, messages, purchases, files, or external systems as sensitive. Require an explicit, visible confirmation immediately before the action unless the user has clearly authorized that exact action.

## Repository map

- `lib/core`: application orchestration, models, and state machine
- `lib/channels`: channel selection and isolated context
- `lib/voice`: capture, voice engine, and speech output contracts
- `lib/translator`: translation contract and implementations
- `lib/remote`: hardware-independent command routing
- `lib/services`: persistence and shared services
- `lib/ui`: Flutter presentation
- `test`: controller, channel, state-machine, command, and widget tests
- `backend`: trusted server-side components when required

## Working rules

- Inspect the affected interfaces and tests before editing.
- Prefer the smallest change that preserves the existing architecture and runnable mock mode.
- Extend existing contracts before introducing parallel abstractions.
- Add or update tests for observable behavior and state transitions, especially cancellation and stale async operations.
- Preserve user changes and avoid unrelated rewrites.
- Do not claim device, microphone, wearable, network, or release behavior was verified unless it was actually exercised in that environment.

## Verification

Run from the repository root when available:

```powershell
C:\src\flutter\bin\dart.bat format --output=none --set-exit-if-changed .
C:\src\flutter\bin\flutter.bat analyze
C:\src\flutter\bin\flutter.bat test
```

If `backend/package.json` is added, also run its declared test command from `backend`. Do not invent a backend test step while that package does not exist.

Use the matching repository skill under `.agents/skills` for feature work, voice, device control, regression checks, or releases. Those skills are eligible for automatic invocation.
