import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class BaseInstallSurfaceTests(unittest.TestCase):
    def test_base_install_scripts_do_not_bundle_stats_or_mcp_assets(self):
        managed_tokens = (
            "dreamers_hook.sh",
            "dreamers_hook.ps1",
            "dreamers_stats.py",
            "dreamers_mcp_server.py",
            "hooks.json",
            "config.toml",
            "mcp_servers.dreamers_stats",
            "dreamers/install-state/codex-bundle.json",
        )
        for relative_path in (
            Path("Install-DreamersCodex.sh"),
            Path("Install-DreamersCodex.ps1"),
            Path("Remove-DreamersCodex.ps1"),
        ):
            content = (REPO_ROOT / relative_path).read_text(encoding="utf-8")
            for token in managed_tokens:
                with self.subTest(file=relative_path.as_posix(), token=token):
                    self.assertNotIn(token, content)

    def test_readme_points_optional_stats_to_dreamers_mcp(self):
        readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("dreamers-mcp", readme)
        self.assertIn("Optional Stats And MCP Bundle", readme)
        self.assertIn("stats-free by default", readme)
