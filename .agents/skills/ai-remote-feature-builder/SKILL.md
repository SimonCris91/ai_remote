---
name: ai-remote-feature-builder
description: Implement or refactor AI Remote Flutter features while preserving its explicit state machine, isolated channel contexts, provider interfaces, and runnable mock mode. Use for ordinary app features and architecture changes; use the dedicated voice, device-control, regression, or release skill when that is the primary task.
---

# AI Remote Feature Builder

Implement the requested behavior within the current architecture.

## Before editing

- Read `AGENTS.md` and the affected code in `lib/core`, then inspect the relevant feature interface and tests.
- Trace the operation through `AppController`, `AiRemoteStateMachine`, and `ChannelManager` when state or channel context is involved.
- Identify the existing contract to extend before adding a new abstraction.

## Preserve these contracts

- Model lifecycle changes as valid `AiRemoteStateMachine` transitions.
- Keep each channel's history in its own `ConversationSession`.
- Keep integrations replaceable through interfaces and dependency injection.
- Maintain the mock implementation as a usable offline development path.
- Protect asynchronous flows against cancellation and stale completions; follow the existing operation-id pattern unless a better tested mechanism replaces it.
- Keep secrets and privileged decisions outside the mobile client.

## Complete the change

Add focused tests for behavior, failure, and cancellation paths. Run formatting, analysis, and tests from the repository root. Report exactly what ran and distinguish code-level verification from testing on a real device or external service.
