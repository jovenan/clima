[English](ARCHITECTURE.md) · **Português**

# Arquitetura

```
 Terminal                    Barra de menus (SwiftUI)
 ┌───────────┐               ┌──────────────────────────────────────┐
 │ clima CLI │               │ ClimatePanel ← ClimateStore          │
 └─────┬─────┘               │                   │ ClimateBackend    │
       │                     │                   ▼                   │
       │                     │             BridgeProcess ────────────┼──┐ JSON por linha
       │                     └──────────────────────────────────────┘  │ (stdin/stdout)
       │                                                               ▼
       │                                                     ┌──────────────────┐
       │                                                     │ clima-bridge     │
       │                                                     │ BridgeHandler    │
       │                                                     └────────┬─────────┘
       ▼                                                              ▼
 ┌────────────────────────────────────────────────────────────────────────────────┐
 │ ClimateService  (conexão persistente · validação · retentativas · disabled)    │
 └───────────────────────────────────────┬────────────────────────────────────────┘
                                         │ ClimateProvider (contrato)
                 ┌───────────────────────┼─────────────────────────┐
                 ▼                       ▼                         ▼
          DemoProvider             MideaProvider            (seu provider)
          (em memória)            (adapter msmart-ng)
```

## Camadas

| Camada | Onde | Responsabilidade | Depende de |
|---|---|---|---|
| Domínio | `clima/core/models.py`, `validation.py`, `errors.py` | `Feature`, `Capabilities`, `DeviceState`, `Changes` e as regras | nada |
| Contrato | `clima/core/provider.py` | `ClimateProvider` e `SetupIO` | domínio |
| Aplicação | `clima/core/service.py`, `registry.py`, `config.py` | conexão, validação, retentativas, escolha do provider | contrato |
| Providers | `clima/providers/` | traduzir para cada fabricante | contrato + SDK do fabricante |
| Interfaces | `clima/cli/`, `clima/bridge/`, `app/` | terminal, protocolo do widget, widget | aplicação |
| Composição | `clima/factory.py` | ligar config → provider → serviço | todas |

O núcleo (`core`) não importa nenhum fabricante. A dependência sempre aponta para dentro.

## Padrões de projeto

| Padrão | Onde | Para quê |
|---|---|---|
| **Strategy / Adapter** | `ClimateProvider` e cada provider | trocar o fabricante sem tocar no resto; cada provider adapta uma API externa |
| **Registry + Factory** | `core/registry.py` | encontrar providers por nome, incluindo plugins via *entry points* |
| **Facade** | `ClimateService` | uma porta de entrada simples para o CLI e a ponte |
| **Retry com backoff** | `RetryPolicy` | falhas de rede são retentadas; pedidos inválidos, nunca |
| **Command** | `cli/parser.py` (`ShowStatus`, `ApplyChanges`...) e `BridgeHandler._ops` | cada comando/op é um objeto ou uma entrada numa tabela de despacho |
| **Composition Root / DI** | `factory.py`; `ClimateStore(backend:)` | dependências injetadas; o app só conhece o protocolo `ClimateBackend` |
| **Observer** | `ClimateStore` (`ObservableObject`) | as telas se redesenham quando o estado muda |
| **Optimistic UI** | `DeviceState.applying(_:)` + `ClimateStore` | a tela reage na hora e corrige se o aparelho discordar |

## Funcionalidades guiadas por capacidades

1. O provider declara o que suporta em `capabilities()`.
2. O `ClimateService` remove o que o usuário desativou (`disabled_features`).
3. A validação recusa pedidos fora das capacidades, **antes** de qualquer comando sair.
4. O CLI mostra só as linhas suportadas; o widget mostra só as seções suportadas.

## Protocolo da ponte

Uma requisição por linha no stdin, uma resposta por linha no stdout. Os logs vão para o stderr.

```json
{"id": 1, "op": "snapshot"}
{"id": 2, "op": "apply", "changes": {"power": true, "target_temperature": 23}}

{"id": 1, "ok": true, "state": {...}, "capabilities": {...}}
{"id": 2, "ok": false, "error": "temperature must be between 16 and 30", "kind": "invalid"}
```

`kind` pode ser `invalid` (pedido), `device` (comunicação), `config` (falta `clima setup`) ou `internal`.

O app reinicia a ponte se ela morrer, expira pedidos sem resposta após 45 s e aceita respostas fora de ordem (casadas pelo `id`).
