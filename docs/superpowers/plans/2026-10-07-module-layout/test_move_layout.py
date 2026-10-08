"""Unit tests for the one-off move_layout script (deleted with it in the plan's last task)."""

from __future__ import annotations

import unittest

from move_layout import (
    add_folder_variables,
    ensure_services,
    inline_folder_aliases,
    instance_path,
    map_parts,
    rename_bindings,
    rename_command,
    rename_in_comments,
    rename_prose,
    rename_quoted,
    rewrite_paths,
    rewrite_relative_requires,
)

MOVES = {
    "ReplicatedStorage/Shared/Modules/Guard": "ReplicatedStorage/Shared/Core/Guard",
    "ServerScriptService/Services/BankService/BankRequests": "ServerScriptService/Features/Bank/Net/BankReceiver",
    "ServerScriptService/Services/BankService/BankServiceServer": "ServerScriptService/Features/Bank/BankServiceServer",
    "ReplicatedStorage/Client/Services/VoiceService/VoiceWiring": "ReplicatedStorage/Client/Features/Voice/State/VoiceWiringTracker",
    "ReplicatedStorage/Client/Services/VoiceService/VoiceSettings": "ReplicatedStorage/Shared/Features/Voice/Rules/VoiceSettingsCheck",
}


class Paths(unittest.TestCase):
    def test_instance_path(self) -> None:
        self.assertEqual(instance_path("src/A/B/C.luau"), ("A", "B", "C"))
        self.assertEqual(instance_path("src/A/B/C.spec.luau"), ("A", "B", "C.spec"))
        self.assertEqual(instance_path("src/A/Run.server.luau"), ("A", "Run"))
        self.assertIsNone(instance_path("tasks/runTests.luau"))

    def test_spec_follows_its_module(self) -> None:
        old = ("ServerScriptService", "Services", "BankService", "BankRequests.spec")
        self.assertEqual(map_parts(old, MOVES), ("ServerScriptService", "Features", "Bank", "Net", "BankReceiver.spec"))

    def test_dotted_and_slash_paths(self) -> None:
        text = (
            "require(ReplicatedStorage.Shared.Modules.Guard)\n"
            '["ServerScriptService.Services.BankService.BankRequests"] = "shell",\n'
            "src/ServerScriptService/Services/BankService/BankRequests.spec.luau\n"
            "ReplicatedStorage.Shared.Modules.GuardRails\n"
        )
        self.assertEqual(
            rewrite_paths(text, MOVES),
            "require(ReplicatedStorage.Shared.Core.Guard)\n"
            '["ServerScriptService.Features.Bank.Net.BankReceiver"] = "shell",\n'
            "src/ServerScriptService/Features/Bank/Net/BankReceiver.spec.luau\n"
            "ReplicatedStorage.Shared.Modules.GuardRails\n",
        )


class RelativeRequires(unittest.TestCase):
    def test_siblings_that_stay_siblings_stay_relative(self) -> None:
        spec = ("ServerScriptService", "Services", "BankService", "BankRequests.spec")
        text, needed = rewrite_relative_requires("require(script.Parent.BankRequests)", spec, MOVES)
        self.assertEqual((text, needed), ("require(script.Parent.BankReceiver)", set()))

    def test_siblings_become_absolute_outside_a_spec(self) -> None:
        me = ("ServerScriptService", "Services", "BankService", "BankServiceServer")
        text, needed = rewrite_relative_requires("require(script.Parent.BankRequests)", me, MOVES)
        self.assertEqual(text, "require(ServerScriptService.Features.Bank.Net.BankReceiver)")
        self.assertEqual(needed, {"ServerScriptService"})

    def test_split_siblings_become_absolute(self) -> None:
        me = ("ReplicatedStorage", "Client", "Services", "VoiceService", "VoiceWiring")
        text, needed = rewrite_relative_requires("require(script.Parent.VoiceSettings)", me, MOVES)
        self.assertEqual(text, "require(ReplicatedStorage.Shared.Features.Voice.Rules.VoiceSettingsCheck)")
        self.assertEqual(needed, {"ReplicatedStorage"})

    def test_untouched_when_nothing_moves(self) -> None:
        me = ("ReplicatedStorage", "Client", "UI", "Scenes", "SceneHost")
        text, _ = rewrite_relative_requires("require(script.Parent.SceneRegistry)", me, MOVES)
        self.assertEqual(text, "require(script.Parent.SceneRegistry)")

    def test_ensure_services_adds_a_missing_service_once(self) -> None:
        text = '--!strict\nlocal Players = game:GetService("Players")\n'
        once = ensure_services(text, {"ReplicatedStorage"})
        self.assertEqual(
            once,
            '--!strict\nlocal ReplicatedStorage = game:GetService("ReplicatedStorage")\n'
            'local Players = game:GetService("Players")\n',
        )
        self.assertEqual(ensure_services(once, {"ReplicatedStorage"}), once)


class FolderVariables(unittest.TestCase):
    CLIENT = "ReplicatedStorage.Client.Features.Replication"

    def test_three_requires_from_one_folder_get_a_variable(self) -> None:
        text = (
            'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n\n'
            f"local A = require({self.CLIENT}.Systems.ReplicationOwnerRigSystem)\n"
            f"local B = require({self.CLIENT}.State.ReplicationPuppetPool)\n"
            f"local C = require({self.CLIENT}.Net.ReplicationUplinkSender)\n"
        )
        out, collisions = add_folder_variables(text)
        self.assertEqual(
            out,
            'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n\n'
            f"local ReplicationClient = {self.CLIENT}\n"
            "local A = require(ReplicationClient.Systems.ReplicationOwnerRigSystem)\n"
            "local B = require(ReplicationClient.State.ReplicationPuppetPool)\n"
            "local C = require(ReplicationClient.Net.ReplicationUplinkSender)\n",
        )
        self.assertEqual(collisions, [])

    def test_two_requires_stay_full_addresses(self) -> None:
        text = (
            f"local A = require({self.CLIENT}.Systems.ReplicationOwnerRigSystem)\n"
            f"local B = require({self.CLIENT}.State.ReplicationPuppetPool)\n"
        )
        self.assertEqual(add_folder_variables(text), (text, []))

    def test_existing_variable_takes_new_requires(self) -> None:
        text = (
            f"local ReplicationClient = {self.CLIENT}\n"
            "local A = require(ReplicationClient.Systems.ReplicationOwnerRigSystem)\n"
            f"local B = require({self.CLIENT}.State.ReplicationPuppetPool)\n"
        )
        out, _ = add_folder_variables(text)
        self.assertIn("local B = require(ReplicationClient.State.ReplicationPuppetPool)\n", out)
        self.assertEqual(out.count("local ReplicationClient ="), 1)

    def test_taken_name_is_reported(self) -> None:
        text = "local ReplicationClient = 5\n" + "".join(
            f"local M{i} = require({self.CLIENT}.Net.X{i})\n" for i in range(3)
        )
        self.assertEqual(add_folder_variables(text), (text, ["ReplicationClient"]))

    def test_realm_names(self) -> None:
        text = "".join(f"local M{i} = require(ServerScriptService.Features.Bank.Net.X{i})\n" for i in range(3))
        self.assertIn("local BankServer = ServerScriptService.Features.Bank\n", add_folder_variables(text)[0])


class FolderAliases(unittest.TestCase):
    def test_alias_is_inlined_and_dropped(self) -> None:
        text = (
            "local Folder = ServerScriptService.Services.BankService\n"
            "local BankRequests = require(Folder.BankRequests)\n"
        )
        modules = {("ServerScriptService", "Services", "BankService", "BankRequests")}
        self.assertEqual(
            inline_folder_aliases(text, MOVES, modules),
            "local BankRequests = require(ServerScriptService.Features.Bank.Net.BankReceiver)\n",
        )

    def test_alias_named_like_its_folder_is_dropped(self) -> None:
        moves = {"ReplicatedStorage/Shared/Modules/Constants/Animations/Actions": "ReplicatedStorage/Shared/Features/Animation/Data/AnimationActionRegistry"}
        text = (
            "local Animations = ReplicatedStorage.Shared.Modules.Constants.Animations\n"
            "local Actions = require(Animations.Actions)\n"
        )
        self.assertEqual(
            inline_folder_aliases(text, moves, set()),
            "local Actions = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationActionRegistry)\n",
        )

    def test_alias_named_only_in_a_comment_is_dropped(self) -> None:
        text = (
            "local Folder = ServerScriptService.Services.BankService\n"
            "-- Folder holds the bank modules\n"
            "local BankRequests = require(Folder.BankRequests)\n"
        )
        self.assertNotIn("local Folder = ", inline_folder_aliases(text, MOVES, set()))

    def test_alias_still_used_elsewhere_is_kept(self) -> None:
        text = (
            "local Folder = ServerScriptService.Services.BankService\n"
            "local BankRequests = require(Folder.BankRequests)\n"
            "print(Folder:GetChildren())\n"
        )
        self.assertIn("local Folder = ", inline_folder_aliases(text, MOVES, set()))


class Renames(unittest.TestCase):
    RENAMES = {"BankRequests": "BankReceiver", "RigOutfit": "CustomizationRigOutfitTracker", "Admin": "AdminRules"}

    def test_requirer_local_renamed_but_not_fields(self) -> None:
        text = (
            "local RigOutfit = require(X.CustomizationRigOutfitTracker)\n"
            "local p: RigOutfit.Piece = RigOutfit.new()\nlocal q = other.RigOutfit\n"
        )
        renamed, skipped = rename_bindings(text, self.RENAMES, own=None)
        self.assertEqual(
            renamed,
            "local CustomizationRigOutfitTracker = require(X.CustomizationRigOutfitTracker)\n"
            "local p: CustomizationRigOutfitTracker.Piece = CustomizationRigOutfitTracker.new()\n"
            "local q = other.RigOutfit\n",
        )
        self.assertEqual(skipped, [])

    def test_requirer_own_named_type_follows(self) -> None:
        text = "local RigOutfit = require(X.CustomizationRigOutfitTracker)\nlocal o: RigOutfit.RigOutfit\n"
        renamed, _ = rename_bindings(text, self.RENAMES, own=None)
        self.assertIn("local o: CustomizationRigOutfitTracker.CustomizationRigOutfitTracker\n", renamed)

    def test_own_file_renames_its_type_too(self) -> None:
        text = "local RigOutfit = {}\nexport type RigOutfit = {}\nreturn RigOutfit\n"
        renamed, skipped = rename_bindings(text, self.RENAMES, own="CustomizationRigOutfitTracker")
        self.assertEqual(
            renamed,
            "local CustomizationRigOutfitTracker = {}\nexport type CustomizationRigOutfitTracker = {}\n"
            "return CustomizationRigOutfitTracker\n",
        )
        self.assertEqual(skipped, [])

    def test_requirer_with_its_own_type_alias_is_skipped(self) -> None:
        text = "local RigOutfit = require(X.CustomizationRigOutfitTracker)\ntype RigOutfit = RigOutfit.RigOutfit\n"
        self.assertEqual(rename_bindings(text, self.RENAMES, own=None), (text, ["RigOutfit"]))

    def test_comments_rename_but_code_and_strings_do_not(self) -> None:
        text = '-- RigOutfit tracks rigs\nlocal s = "RigOutfit -- RigOutfit"\n--[[ RigOutfit ]]\nlocal RigOutfitX = 1\n'
        self.assertEqual(
            rename_in_comments(text, self.RENAMES),
            "-- CustomizationRigOutfitTracker tracks rigs\n"
            'local s = "RigOutfit -- RigOutfit"\n'
            "--[[ CustomizationRigOutfitTracker ]]\nlocal RigOutfitX = 1\n",
        )

    def test_unrelated_file_untouched(self) -> None:
        text = "-- BankRequests is mentioned here\n"
        self.assertEqual(rename_bindings(text, self.RENAMES, own="Other"), (text, []))

    def test_quoted_skips_single_words(self) -> None:
        text = 'dependencies = { "BankRequests" }, group = "Admin"'
        self.assertEqual(rename_quoted(text, self.RENAMES), 'dependencies = { "BankReceiver" }, group = "Admin"')

    def test_prose_renames_distinctive_names_only(self) -> None:
        text = "BankRequests wires packets. Admin rules. Path: Bank/BankRequests.\n"
        self.assertEqual(
            rename_prose(text, self.RENAMES), "BankReceiver wires packets. Admin rules. Path: Bank/BankRequests.\n"
        )

    def test_command_name(self) -> None:
        text = 'return {\n\tName = "addcurrency",\n\tArgs = { { Name = "target" } },\n}\n'
        self.assertEqual(
            rename_command(text, "AddCurrency", "CurrencyAdd"),
            'return {\n\tName = "currencyadd",\n\tArgs = { { Name = "target" } },\n}\n',
        )


if __name__ == "__main__":
    unittest.main()
