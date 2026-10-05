---
name: ai-remote-regression-check
description: Validate AI Remote changes with focused Flutter tests, formatting, static analysis, and explicit runtime boundaries. Use for regression checks, bug-fix verification, pre-merge review, or when confirming that channel, state, voice, translation, and remote-command behavior still works.
---

# AI Remote Regression Check

Inspect the change and select tests that exercise behavior rather than generated text or implementation details.

## Required baseline

From the repository root run:

```powershell
C:\src\flutter\bin\dart.bat format --output=none --set-exit-if-changed .
C:\src\flutter\bin\flutter.bat analyze
C:\src\flutter\bin\flutter.bat test
```

If a command cannot run, report the exact boundary and continue with the safe checks that remain available.

## High-value invariants

- Previous/next wrap correctly and selected-channel persistence restores safely.
- Conversation context cannot leak across channels.
- Valid state transitions succeed and invalid transitions fail predictably.
- Push-to-talk, translation, speech output, cancellation, and stale-result protection preserve the state machine.
- Every `RemoteCommand` routes exactly once to the intended action.
- Mock mode remains runnable without network credentials.
- UI tests instantiate `AiRemoteApp` with its required controller; remove obsolete Flutter template assumptions when encountered.

Summarize failures by cause and affected behavior. Do not call a build, device, microphone, wearable, backend, or live API verified unless that environment was actually exercised.
