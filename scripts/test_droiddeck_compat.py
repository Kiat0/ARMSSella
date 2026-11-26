"""Hermetic unit tests for DroidDeck and extended Armada OS / ARM64 compatibility."""

import os
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Ensure src is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src")))


def _make_elf_header(machine: int) -> bytes:
    """Build a minimal 20-byte little-endian ELF64 header with given e_machine."""
    # e_ident (16 bytes) + e_type (2) + e_machine (2)
    ident = b"\x7fELF\x02\x01\x01" + b"\x00" * 9
    return ident + struct.pack("<HH", 2, machine)


class TestDroidDeckAndArmadaCompat(unittest.TestCase):
    _ENV_KEYS = (
        "ASSELLA_FORCE_ARM64",
        "ASSELLA_FORCE_ARMADA",
        "ASSELLA_FORCE_DROIDDECK",
        "DD_DESKTOP",
        "DD_LAUNCH_DIR",
        "DD_INSIDE",
        "DDNATV_ROOT",
        "DD_STEAM_CLIENT_ARCH",
        "DD_X64_HOME",
        "DROIDDECK_PACKAGE",
        "STEAM_ROOT",
        "XDG_DATA_HOME",
    )

    def setUp(self):
        self._saved = {k: os.environ.get(k) for k in self._ENV_KEYS}
        for k in self._ENV_KEYS:
            os.environ.pop(k, None)

    def tearDown(self):
        for k, v in self._saved.items():
            if v is not None:
                os.environ[k] = v
            else:
                os.environ.pop(k, None)

    def test_droiddeck_detection_env_and_markers(self):
        from utils.helpers import is_droiddeck, get_platform_label

        os.environ["ASSELLA_FORCE_DROIDDECK"] = "1"
        self.assertTrue(is_droiddeck())
        self.assertEqual(get_platform_label(), "DroidDeck")

        os.environ["ASSELLA_FORCE_DROIDDECK"] = "0"
        os.environ["DD_DESKTOP"] = "1"
        self.assertFalse(is_droiddeck())

        os.environ.pop("ASSELLA_FORCE_DROIDDECK", None)
        self.assertTrue(is_droiddeck())

        os.environ.pop("DD_DESKTOP", None)
        os.environ["DDNATV_ROOT"] = "/data/user/0/com.droiddeck.launcher/files/rootfs"
        self.assertTrue(is_droiddeck())

        os.environ.pop("DDNATV_ROOT", None)
        with patch("os.path.exists", side_effect=lambda p: p == "/usr/local/bin/droiddeck-session"):
            self.assertTrue(is_droiddeck())

        with patch("os.path.exists", return_value=False):
            self.assertFalse(is_droiddeck())

    def test_dotnet_env_sets_android_flags_only_on_droiddeck(self):
        from utils.helpers import get_dotnet_env

        os.environ["ASSELLA_FORCE_DROIDDECK"] = "1"
        dd_env = get_dotnet_env()
        self.assertEqual(dd_env.get("DOTNET_EnableWriteXorExecute"), "0")
        self.assertEqual(dd_env.get("COMPlus_EnableWriteXorExecute"), "0")
        self.assertEqual(dd_env.get("DOTNET_gcServer"), "0")
        self.assertEqual(dd_env.get("DOTNET_EnableDiagnostics"), "0")
        self.assertEqual(dd_env.get("DOTNET_SYSTEM_GLOBALIZATION_INVARIANT"), "1")

        os.environ["ASSELLA_FORCE_DROIDDECK"] = "0"
        with patch.dict(os.environ, {}, clear=False):
            for k in (
                "DOTNET_EnableWriteXorExecute",
                "COMPlus_EnableWriteXorExecute",
                "DOTNET_gcServer",
                "DOTNET_EnableDiagnostics",
            ):
                os.environ.pop(k, None)
            normal_env = get_dotnet_env()
            self.assertNotIn("DOTNET_EnableWriteXorExecute", normal_env)

    def test_elf_detection_and_fex_wrapping(self):
        from utils.helpers import get_elf_machine, is_x86_elf, wrap_command_for_arm64

        with tempfile.TemporaryDirectory() as tmp:
            x64_bin = Path(tmp) / "schema-grabber"
            arm_bin = Path(tmp) / "native-arm64"
            py_script = Path(tmp) / "script.py"
            x64_bin.write_bytes(_make_elf_header(62))
            arm_bin.write_bytes(_make_elf_header(183))
            py_script.write_text("#!/usr/bin/env python3\nprint('ok')\n")

            self.assertEqual(get_elf_machine(x64_bin), 62)
            self.assertEqual(get_elf_machine(arm_bin), 183)
            self.assertIsNone(get_elf_machine(py_script))
            self.assertTrue(is_x86_elf(x64_bin))
            self.assertFalse(is_x86_elf(arm_bin))
            self.assertFalse(is_x86_elf(py_script))

            os.environ["ASSELLA_FORCE_ARM64"] = "1"
            with patch("sys.platform", "linux"):
                # DroidDeck FEX wrapper takes priority when present
                with patch("os.path.isfile", side_effect=lambda p: p in (str(x64_bin), "/usr/local/bin/droiddeck-fex")), \
                     patch("os.access", return_value=True):
                    wrapped = wrap_command_for_arm64([str(x64_bin), "arg1"])
                    self.assertEqual(
                        wrapped,
                        ["/usr/local/bin/droiddeck-fex", "run", "--mode", "on", "--", str(x64_bin), "arg1"],
                    )

                # Armada OS FEXInterpreter fallback
                with patch("os.path.isfile", side_effect=lambda p: p == str(x64_bin)), \
                     patch("shutil.which", side_effect=lambda name: "/usr/bin/FEXInterpreter" if name == "FEXInterpreter" else None):
                    wrapped = wrap_command_for_arm64([str(x64_bin), "arg1"])
                    self.assertEqual(wrapped, ["/usr/bin/FEXInterpreter", str(x64_bin), "arg1"])

                # Native ARM64 ELF is never wrapped
                self.assertEqual(wrap_command_for_arm64([str(arm_bin), "arg1"]), [str(arm_bin), "arg1"])

    def test_slscheevo_prefers_python_script_over_x86_binary_on_arm64(self):
        from utils.helpers import get_slscheevo_path

        os.environ["ASSELLA_FORCE_ARM64"] = "1"
        with tempfile.TemporaryDirectory() as tmp:
            sl_dir = Path(tmp) / "SLScheevo"
            sl_dir.mkdir(parents=True)
            bin_name = "SLScheevo.exe" if sys.platform == "win32" else "SLScheevo"
            (sl_dir / bin_name).write_bytes(_make_elf_header(62))
            script = sl_dir / "SLScheevo.py"
            script.write_text("#!/usr/bin/env python3\n")

            with patch("utils.paths.Paths.DEPS", Path(tmp)):
                chosen = get_slscheevo_path()
                self.assertEqual(chosen.resolve(), script.resolve())

    def test_armada_and_droiddeck_steam_manifests_and_paths(self):
        import core.steam_helpers as sh

        with tempfile.TemporaryDirectory() as tmp_home:
            # 1. Armada OS real manifest filename: steam_client_steamdeck_stable_linuxarm64.manifest
            steam_dir = Path(tmp_home) / ".local" / "share" / "Steam"
            (steam_dir / "steamrtarm64").mkdir(parents=True)
            pkg = steam_dir / "package"
            pkg.mkdir(parents=True)
            (pkg / "steam_client_steamdeck_stable_linuxarm64.manifest").write_text(
                '"linuxarm64"\n{\n\t"version"\t"1799999999"\n}\n',
                encoding="utf-8",
            )

            sh._cached_steam_client_version = None
            sh._steam_client_version_looked_up = False
            sh.invalidate_steam_env_cache()
            with patch("pathlib.Path.home", return_value=Path(tmp_home)):
                ver = sh.get_installed_steam_client_version(force_refresh=True)
                self.assertEqual(ver, "1799999999")

            # 2. DroidDeck experimental x86-64 FEX Steam client path
            x64_home = Path(tmp_home) / ".droiddeck-x64"
            x64_steam = x64_home / ".local" / "share" / "Steam"
            (x64_steam / "steamrt64").mkdir(parents=True)
            os.environ["DD_STEAM_CLIENT_ARCH"] = "x86_64"
            os.environ["DD_X64_HOME"] = str(x64_home)
            with patch("os.path.expanduser", return_value=tmp_home):
                found = sh._find_steam_linux()
                self.assertEqual(os.path.realpath(found), os.path.realpath(str(x64_steam)))

    def test_no_systemd_on_droiddeck(self):
        from utils.companions import have_systemd_user
        from ui.dialogs.settings_tabs.webui_tab import get_service_status, is_service_enabled

        os.environ["ASSELLA_FORCE_DROIDDECK"] = "1"
        with patch("subprocess.run") as mock_run:
            self.assertFalse(have_systemd_user())
            self.assertEqual(get_service_status(), "unavailable")
            self.assertFalse(is_service_enabled())
            mock_run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
