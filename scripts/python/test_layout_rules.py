"""Unit tests for layout_rules. Run: python3 -m unittest discover -s scripts/python -p "test_*.py"."""

from __future__ import annotations

import unittest

from layout_rules import check_layout, module_name

SHARED = "src/ReplicatedStorage/Shared/Features/"
CLIENT = "src/ReplicatedStorage/Client/Features/"
SERVER = "src/ServerScriptService/Features/"
COMMANDS = "src/ServerScriptService/Commands/"


def errors_for(*paths: str, files: dict[str, str] | None = None) -> list[str]:
    texts = files or {}
    return check_layout(paths, lambda path: texts.get(path, ""))


class ModuleName(unittest.TestCase):
    def test_strips_extension_and_tags(self) -> None:
        self.assertEqual(module_name(f"{SHARED}Bank/Net/BankEvents.spec.luau"), "BankEvents")
        self.assertEqual(module_name("src/ServerScriptService/ServerHandler.server.luau"), "ServerHandler")
        self.assertEqual(module_name("src/ReplicatedStorage/Client/UI/React/GameUI.storybook.luau"), "GameUI")


class Placement(unittest.TestCase):
    def test_compliant_feature_passes(self) -> None:
        self.assertEqual(
            errors_for(
                f"{SHARED}Bank/Data/BankConstants.luau",
                f"{SHARED}Bank/Net/BankEvents.luau",
                f"{SHARED}Bank/Net/BankEvents.spec.luau",
                f"{CLIENT}Bank/BankServiceClient.luau",
                f"{SERVER}Bank/BankServiceServer.luau",
                f"{SERVER}Bank/Net/BankReceiver.luau",
            ),
            [],
        )

    def test_outside_features_list_passes(self) -> None:
        self.assertEqual(
            errors_for(
                "src/ReplicatedStorage/Shared/Core/Logger.luau",
                "src/ServerScriptService/Core/Testing/SpecRoots.luau",
                "src/ReplicatedStorage/Shared/Data/PlayerDataTypes.luau",
                "src/ReplicatedStorage/Shared/CmdrTypes/currencyType.luau",
                "src/ServerScriptService/ServerHandler.server.luau",
                "src/StarterPlayer/StarterCharacterScripts/Animate.client.luau",
            ),
            [],
        )

    def test_loose_module_fails(self) -> None:
        [error] = errors_for("src/ReplicatedStorage/Shared/Modules/Guard.luau")
        self.assertIn("outside every Features/<Feature>/ root", error)

    def test_too_deep_fails(self) -> None:
        [error] = errors_for(f"{SHARED}Bank/Net/Extra/BankEvents.luau")
        self.assertIn("too deep", error)

    def test_unknown_subfolder_fails(self) -> None:
        [error] = errors_for(f"{SHARED}Bank/Signals/BankSignal.luau")
        self.assertIn("not a subfolder kind", error)
        self.assertIn("user's approval", error)


class Naming(unittest.TestCase):
    def test_missing_feature_prefix_fails(self) -> None:
        [error] = errors_for(f"{SHARED}Bank/Net/MoneyEvents.luau")
        self.assertIn("must start with its feature, `Bank`", error)

    def test_wrong_role_word_fails(self) -> None:
        [error] = errors_for(f"{SHARED}Bank/State/BankHelper.luau")
        self.assertIn("State/ role word", error)

    def test_spec_judged_by_its_module(self) -> None:
        [error] = errors_for(f"{SHARED}Bank/Net/BankHelper.spec.luau")
        self.assertIn("Net/ role word", error)


class Services(unittest.TestCase):
    def test_root_file_must_be_the_service(self) -> None:
        [error] = errors_for(f"{SERVER}Bank/BankHelper.luau")
        self.assertIn("only `BankServiceServer` sits at the feature root", error)

    def test_second_service_fails(self) -> None:
        errors = errors_for(f"{SERVER}Bank/BankServiceServer.luau", f"{SERVER}Bank/BankAuditServiceServer.luau")
        self.assertEqual(len(errors), 1)
        self.assertIn("BankAuditServiceServer", errors[0])

    def test_realm_suffix_must_match(self) -> None:
        [error] = errors_for(f"{CLIENT}Bank/BankServiceServer.luau")
        self.assertIn("BankServiceClient", error)

    def test_shared_realm_has_no_service(self) -> None:
        [error] = errors_for(f"{SHARED}Bank/BankServiceServer.luau")
        self.assertIn("shared realm has no services", error)


class Commands(unittest.TestCase):
    def test_feature_first_command_with_matching_name_passes(self) -> None:
        path = f"{COMMANDS}CurrencyAdd.luau"
        errors = errors_for(
            f"{SERVER}Currency/CurrencyServiceServer.luau",
            path,
            f"{COMMANDS}CurrencyAddServer.luau",
            files={path: 'return {\n\tName = "currencyadd",\n\tArgs = { { Name = "target" } },\n}\n'},
        )
        self.assertEqual(errors, [])

    def test_name_must_match_file(self) -> None:
        path = f"{COMMANDS}CurrencyAdd.luau"
        [error] = errors_for(
            f"{SERVER}Currency/CurrencyServiceServer.luau", path, files={path: 'Name = "addcurrency",'}
        )
        self.assertIn('"currencyadd"', error)

    def test_command_must_start_with_a_feature(self) -> None:
        path = f"{COMMANDS}AddCurrency.luau"
        errors = errors_for(
            f"{SERVER}Currency/CurrencyServiceServer.luau", path, files={path: 'Name = "addcurrency",'}
        )
        self.assertTrue(any("must start with its feature's name" in e for e in errors))


class UiTree(unittest.TestCase):
    def test_pascal_and_hooks_pass(self) -> None:
        self.assertEqual(
            errors_for(
                "src/ReplicatedStorage/Client/UI/React/Hooks/useStore.luau",
                "src/ReplicatedStorage/Client/UI/React/Debugger/DebuggerTheme.luau",
            ),
            [],
        )

    def test_lowercase_module_fails(self) -> None:
        [error] = errors_for("src/ReplicatedStorage/Client/UI/React/Debugger/theme.luau")
        self.assertIn("PascalCase", error)


if __name__ == "__main__":
    unittest.main()
