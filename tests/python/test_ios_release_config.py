import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class IOSReleaseConfigTests(unittest.TestCase):
    def test_ios_preset_is_configured_for_sierra_team(self):
        preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        match = re.search(
            r"\[preset\.1\]\s+(.*?)(?=\n\[preset\.1\.options\])",
            preset,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(match)
        self.assertIn('name="iOS"', match.group(1))
        self.assertIn('platform="iOS"', match.group(1))
        self.assertIn('export_path="build/ios/PlayTable.xcodeproj"', match.group(1))
        self.assertIn("application/export_project_only=true", preset)

        options = re.search(
            r"\[preset\.1\.options\]\s+(.*?)(?=\n\[|\Z)",
            preset,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(options)
        ios_options = options.group(1)
        self.assertIn('application/app_store_team_id="28X7P94SF5"', ios_options)
        self.assertIn('application/bundle_identifier="org.playtable.app"', ios_options)
        self.assertIn('application/min_ios_version="14.0"', ios_options)
        self.assertNotRegex(ios_options, r"(?i)(password|private[_-]?key|secret)=")

    def test_ios_version_script_matches_the_app_version(self):
        result = subprocess.run(
            ["bash", "scripts/ios_version.sh"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        values = dict(
            line.split("=", 1)
            for line in result.stdout.splitlines()
            if "=" in line
        )
        self.assertEqual(values["VERSION_NAME"], "1.0")
        self.assertEqual(values["BUILD_NUMBER"], "17")

    def test_app_store_workflow_is_mac_only_and_uses_runtime_secrets(self):
        workflow = (ROOT / ".github/workflows/release-appstore.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("runs-on: macos-latest", workflow)
        self.assertIn("APPLE_TEAM_ID: \"28X7P94SF5\"", workflow)
        self.assertIn("IOS_BUNDLE_ID: \"org.playtable.app\"", workflow)
        self.assertIn("APPSTORE_CONNECT_API_KEY_ID", workflow)
        self.assertIn("APPSTORE_CONNECT_ISSUER_ID", workflow)
        self.assertIn("APPSTORE_CONNECT_API_PRIVATE_KEY_BASE64", workflow)
        self.assertIn("IOS_CERTIFICATE_BASE64", workflow)
        self.assertIn("IOS_PROVISIONING_PROFILE_BASE64", workflow)
        self.assertIn("CODE_SIGN_STYLE=Manual", (ROOT / "fastlane/Fastfile").read_text(encoding="utf-8"))
        self.assertIn("destination", workflow)
        self.assertIn("testflight", workflow)
        self.assertIn("appstore", workflow)
        self.assertIn("startsWith(github.ref, 'refs/tags/ios-v')", workflow)
        self.assertIn("IOS_EXPORT_COMPLIANCE_USES_ENCRYPTION", workflow)
        self.assertIn("IOS_EXPORT_COMPLIANCE_IS_EXEMPT", workflow)
        self.assertNotIn("Banlek", workflow)
        self.assertNotIn("banlek", workflow)

    def test_app_store_delivery_includes_all_localized_metadata_and_screenshots(self):
        fastfile = (ROOT / "fastlane/Fastfile").read_text(encoding="utf-8")
        self.assertIn('skip_metadata: false', fastfile)
        self.assertIn('skip_screenshots: false', fastfile)
        self.assertIn('submit_for_review:', fastfile)
        self.assertIn('automatic_release:', fastfile)
        self.assertIn('app_review_information:', fastfile)
        self.assertIn('submission_information:', fastfile)

        for locale in ("pt-BR", "en-US", "es-ES"):
            metadata_dir = ROOT / "fastlane/metadata" / locale
            self.assertTrue((metadata_dir / "name.txt").is_file())
            self.assertTrue((metadata_dir / "description.txt").is_file())
            self.assertTrue((metadata_dir / "keywords.txt").is_file())
            self.assertTrue((metadata_dir / "support_url.txt").is_file())
            self.assertTrue((metadata_dir / "privacy_url.txt").is_file())
            screenshots_dir = ROOT / "fastlane/screenshots" / locale
            self.assertEqual(3, len(list(screenshots_dir.glob("iPhone 6.5-*.png"))))
            self.assertEqual(
                3,
                len(
                    list(
                        screenshots_dir.glob(
                            "iPad Pro (12.9-inch) (3rd generation)-*.png"
                        )
                    )
                ),
            )

        screenshot_script = (ROOT / "scripts/ios_store_screenshots.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("iPad Pro (12.9-inch) (3rd generation)", screenshot_script)
        self.assertIn("2048x2732", screenshot_script)

    def test_ios_export_checks_the_embedded_app_icon(self):
        export_script = (ROOT / "scripts/ios_export.sh").read_text(encoding="utf-8")
        self.assertIn("AppIcon.appiconset/Icon-1024.png", export_script)
        self.assertIn("1024x1024", export_script)


if __name__ == "__main__":
    unittest.main()
