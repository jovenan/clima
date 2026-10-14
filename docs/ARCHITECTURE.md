**English** · [Português](ARCHITECTURE.pt-BR.md)

# Architecture

```
 Terminal                    Menu bar (SwiftUI)
 ┌───────────┐               ┌──────────────────────────────────────┐
 │ clima CLI │               │ ClimatePanel ← ClimateStore          │
 └─────┬─────┘               │                   │ ClimateBackend    │
       │                     │                   ▼                   │
       │                     │             BridgeProcess ────────────┼──┐ line-delimited JSON
       │                     └──────────────────────────────────────┘  │ (stdin/stdout)
       │                                                               ▼
       │                                                     ┌──────────────────┐
       │                                                     │ clima-bridge     │
       │                                                     │ BridgeHandler    │
       │                                                     └────────┬─────────┘
       ▼                                                              ▼
 ┌────────────────────────────────────────────────────────────────────────────────┐
 │ ClimateService  (persistent connection · validation · retries · disabled)      │
 └───────────────────────────────────────┬────────────────────────────────────────┘
                                         │ ClimateProvider (contract)
                 ┌───────────────────────┼─────────────────────────┐
                 ▼                       ▼                         ▼
          DemoProvider             MideaProvider            (your provider)
          (in memory)             (msmart-ng adapter)
```

## Layers

| Layer | Where | Responsibility | Depends on |
|---|---|---|---|
| Domain | `clima/core/models.py`, `validation.py`, `errors.py` | `Feature`, `Capabilities`, `DeviceState`, `Changes` and the rules | nothing |
| Contract | `clima/core/provider.py` | `ClimateProvider` and `SetupIO` | domain |
| Application | `clima/core/service.py`, `registry.py`, `config.py` | connection, validation, retries, provider selection | contract |
| Providers | `clima/providers/` | translating to each manufacturer | contract + vendor SDK |
| Interfaces | `clima/cli/`, `clima/bridge/`, `app/` | terminal, widget protocol, widget | application |
| Composition | `clima/factory.py` | wiring config → provider → service | all |

The core (`core`) imports no manufacturer. Dependencies always point inwards.

## Design patterns

| Pattern | Where | Why |
|---|---|---|
| **Strategy / Adapter** | `ClimateProvider` and each provider | swap the manufacturer without touching the rest; each provider adapts an external API |
| **Registry + Factory** | `core/registry.py` | find providers by name, including plugins via *entry points* |
| **Facade** | `ClimateService` | a single simple entry point for the CLI and the bridge |
| **Retry with backoff** | `RetryPolicy` | network failures are retried; invalid requests never are |
| **Command** | `cli/parser.py` (`ShowStatus`, `ApplyChanges`...) and `BridgeHandler._ops` | each command/op is an object or an entry in a dispatch table |
| **Composition Root / DI** | `factory.py`; `ClimateStore(backend:)` | dependencies are injected; the app only knows the `ClimateBackend` protocol |
| **Observer** | `ClimateStore` (`ObservableObject`) | views redraw when the state changes |
| **Optimistic UI** | `DeviceState.applying(_:)` + `ClimateStore` | the panel reacts immediately and corrects itself if the device disagrees |

## Capability-driven features

1. The provider declares what it supports in `capabilities()`.
2. `ClimateService` removes what the user disabled (`disabled_features`).
3. Validation rejects requests outside the capabilities **before** any command is sent.
4. The CLI shows only the supported lines; the widget shows only the supported sections.

## Bridge protocol

One request per line on stdin, one response per line on stdout. Logs go to stderr.

```json
{"id": 1, "op": "snapshot"}
{"id": 2, "op": "apply", "changes": {"power": true, "target_temperature": 23}}

{"id": 1, "ok": true, "state": {...}, "capabilities": {...}}
{"id": 2, "ok": false, "error": "temperature must be between 16 and 30", "kind": "invalid"}
```

`kind` is `invalid` (request), `device` (communication), `config` (`clima setup` missing) or `internal`.

The app restarts the bridge if it dies, expires unanswered requests after 45 s and accepts out-of-order responses (matched by `id`).
