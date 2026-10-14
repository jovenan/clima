[English](PROVIDERS.md) · **Português**

# Como adicionar um provider (fabricante)

Um *provider* é o **adapter** entre o Clima e a API de um fabricante. O CLI, a ponte e o widget só conhecem o contrato `ClimateProvider`. Um provider novo funciona em todos eles sem mudar nenhuma outra linha.

Para ver uma implementação completa e pequena, leia **`src/clima/providers/demo.py`**. Para uma real, leia **`src/clima/providers/midea/`**.

## 1. Implemente o contrato

```python
# src/clima/providers/mybrand.py
from typing import Any, Mapping

from ..core import (Capabilities, Changes, ClimateProvider, DeviceError, DeviceState, FanSpeed, Feature,
                    Mode, SetupIO, register)
from ..core.errors import ConfigError

from mybrand_sdk import Client, SdkError  # a biblioteca do fabricante


@register
class MyBrandProvider(ClimateProvider):
    name = "mybrand"                             # usado em "provider" na config e em --provider
    display_name = "My Brand (Wi-Fi)"           # mostrado em `clima providers`

    def __init__(self, settings: Mapping[str, Any]) -> None:
        super().__init__(settings)
        if "host" not in self.settings:
            raise ConfigError("incomplete configuration. Run 'clima setup'.")
        self._client: Client | None = None

    @classmethod
    async def interactive_setup(cls, io: SetupIO) -> dict[str, Any]:
        """Opcional. O que for devolvido aqui é salvo em `settings`."""
        host = io.ask("Device IP")
        return {"host": host}

    async def connect(self) -> None:
        try:
            self._client = await Client.connect(self.settings["host"])
        except SdkError as e:
            raise DeviceError(str(e)) from e

    async def capabilities(self) -> Capabilities:
        # Declare SÓ o que o aparelho realmente faz: o widget e o CLI se montam a partir daqui
        return Capabilities(
            features=frozenset({Feature.POWER, Feature.MODE, Feature.TARGET_TEMPERATURE,
                                Feature.INDOOR_TEMPERATURE, Feature.FAN_SPEED}),
            modes=(Mode.COOL, Mode.HEAT, Mode.FAN),
            fan_speeds=(FanSpeed.AUTO, FanSpeed.LOW, FanSpeed.HIGH),
            min_temperature=17, max_temperature=30, temperature_step=1,
        )

    async def read_state(self) -> DeviceState:
        try:
            raw = await self._client.status()
        except SdkError as e:
            raise DeviceError(str(e)) from e
        return DeviceState(
            power=raw["on"],
            mode={"cooling": Mode.COOL, "heating": Mode.HEAT, "fan": Mode.FAN}.get(raw["mode"]),
            target_temperature=raw["setpoint"],
            indoor_temperature=raw["room"],
            fan_speed={"auto": FanSpeed.AUTO, "1": FanSpeed.LOW, "3": FanSpeed.HIGH}.get(raw["fan"]),
        )

    async def apply(self, changes: Changes) -> None:
        # `changes` já foi validado contra capabilities(): só vêm campos suportados, dentro das faixas
        payload = {}
        if changes.power is not None:
            payload["on"] = changes.power
        if changes.target_temperature is not None:
            payload["setpoint"] = changes.target_temperature
        # ... demais campos
        try:
            await self._client.send(payload)
        except SdkError as e:
            raise DeviceError(str(e)) from e
```

## 2. Regras do contrato

| Regra | Por quê |
|---|---|
| **Falha de comunicação vira `DeviceError`** (ou `OSError`/`TimeoutError`). | O `ClimateService` reconecta e tenta de novo (3×, com espera crescente). |
| **Configuração inválida vira `ConfigError`.** | Aparece para o usuário com a dica de rodar `clima setup`. |
| **Não valide faixas em `apply()`.** | O `ClimateService` valida antes contra `capabilities()`, e um pedido inválido nunca chega ao provider. |
| **`connect()` pode ser chamado de novo** depois de uma falha. | É assim que a reconexão funciona. |
| **`capabilities()` é lido uma vez por conexão.** | Não dependa de leituras momentâneas (ex.: um sensor que às vezes não responde). Declare o sensor e devolva `None` no estado. |
| **Valores que o aparelho controla sozinho** voltam como `None`. | As interfaces mostram "set by the device". |
| **Posição de aleta é `1..louver_positions`**; `None` = sem posição fixa. | Fixar uma posição para a oscilação daquele eixo (o serviço já manda `swing_*=False` junto). |

As funcionalidades possíveis estão em `Feature` (`src/clima/core/models.py`). Cada campo de `Changes` exige uma delas (`FIELD_FEATURES`).

## 3. Registre

**Dentro deste repositório:** use o decorator `@register` e acrescente o módulo em `BUILTIN_PROVIDERS` (`src/clima/core/registry.py`). Se o provider precisar de bibliotecas, declare um *extra* no `pyproject.toml`:

```toml
[project.optional-dependencies]
mybrand = ["mybrand-sdk>=1.0"]
```

Se a biblioteca não estiver instalada, o provider aparece como indisponível em `clima providers`, com o motivo, e os outros continuam funcionando.

**Num pacote separado (plugin):** não precisa mexer aqui. Declare o entry point no `pyproject.toml` do seu pacote e instale-o no mesmo ambiente (`~/.local/share/clima/venv/bin/pip install seu-pacote`):

```toml
[project.entry-points."clima.providers"]
mybrand = "my_package.provider:MyBrandProvider"
```

## 4. Use

```sh
clima setup --provider mybrand
clima                 # deve mostrar só as linhas que você declarou
clima on cool 23
```
