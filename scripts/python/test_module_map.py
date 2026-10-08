"""Unit tests for module_map. Run: python3 -m unittest discover -s scripts/python -p "test_*.py"."""

from __future__ import annotations

import unittest

from module_map import END, START, render, replace_section


class Render(unittest.TestCase):
    def test_groups_by_feature_then_core_and_data(self) -> None:
        body = render(
            [
                "src/ServerScriptService/Features/Bank/Net/BankReceiver.luau",
                "src/ServerScriptService/Features/Bank/Net/BankReceiver.spec.luau",
                "src/ReplicatedStorage/Shared/Features/Bank/Net/BankEvents.luau",
                "src/ReplicatedStorage/Client/Features/Bank/BankServiceClient.luau",
                "src/ReplicatedStorage/Shared/Data/PlayerDataTypes.luau",
                "src/ServerScriptService/Core/Testing/SpecRoots.luau",
                "src/ReplicatedStorage/Shared/Features/Animation/Data/AnimationRegistry.luau",
                "src/ReplicatedStorage/Client/UI/React/LogsPanel.luau",
            ]
        )
        self.assertEqual(
            body,
            "### Animation\n\n| Realm | Module |\n|---|---|\n| shared | `Data/AnimationRegistry` |\n\n"
            "### Bank\n\n| Realm | Module |\n|---|---|\n"
            "| shared | `Net/BankEvents` |\n| client | `BankServiceClient` |\n| server | `Net/BankReceiver` |\n\n"
            "### Core\n\n| Realm | Module |\n|---|---|\n| server | `Testing/SpecRoots` |\n\n"
            "### Data\n\n| Realm | Module |\n|---|---|\n| shared | `PlayerDataTypes` |\n",
        )


class ReplaceSection(unittest.TestCase):
    def test_replaces_only_between_markers(self) -> None:
        doc = f"intro\n{START}\nold map\n{END}\noutro\n"
        self.assertEqual(replace_section(doc, "new map\n"), f"intro\n{START}\n\nnew map\n\n{END}\noutro\n")

    def test_is_stable_when_reapplied(self) -> None:
        doc = f"intro\n{START}\nold\n{END}\n"
        once = replace_section(doc, "map\n")
        self.assertEqual(replace_section(once, "map\n"), once)


if __name__ == "__main__":
    unittest.main()
