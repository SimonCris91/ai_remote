---
name: ai-remote-device-control
description: Implement or review AI Remote wearable, Bluetooth, headset, automotive, media-button, and device-action integrations while keeping commands hardware-independent and sensitive actions controlled. Use when external hardware sends commands or the app performs actions on a phone or connected system.
---

# AI Remote Device Control

Keep the phone as the AI owner and connected hardware as a thin command surface.

## Command boundary

- Emit generic `RemoteCommand` values from adapters and route them through `RemoteCommandHandler`.
- Keep vendor, transport, lifecycle, reconnection, and permission details inside a specific `RemoteAdapter` or platform layer.
- Do not put AI prompts, model credentials, or channel histories on the wearable merely to implement remote control.
- Preserve the existing semantics: previous/next select channels, play starts interaction, and stop finishes or cancels according to current state.
- Add a new generic command only when the product behavior cannot be expressed safely with the existing enum; update exhaustive switches and tests together.

## Safety and platform behavior

Request only the permissions required by the selected platform implementation and explain why they are needed. Device or agent actions involving messages, calls, files, accounts, purchases, settings, or external side effects require a visible confirmation immediately before execution unless the exact action is already authorized.

Test adapter connection/disconnection, command ordering, duplicate input, unavailable hardware, state-dependent stop behavior, and app lifecycle changes. Distinguish unit-test results from verification on a real device or wearable.
