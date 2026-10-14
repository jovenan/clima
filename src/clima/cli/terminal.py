"""`SetupIO` implementation for the terminal."""

from __future__ import annotations

import getpass


class TerminalIO:
    def ask(self, question: str, default: str | None = None) -> str:
        suffix = f" [{default}]" if default else ""
        answer = input(f"{question}{suffix}: ").strip()
        return answer or (default or "")

    def ask_secret(self, question: str) -> str:
        return getpass.getpass(f"{question}: ")

    def info(self, message: str) -> None:
        print(message)
