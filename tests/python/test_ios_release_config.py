import re
import hashlib
import struct
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
        self.assertIn('application/min_ios_version="15.0"', ios_options)
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
        self.assertEqual(values["VERSION_NAME"], "0.9.2")
        self.assertEqual(values["BUILD_NUMBER"], "22")

    def test_touch_input_is_explicitly_emulated_for_ios_controls(self):
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn("[input_devices]", project)
        self.assertIn("pointing/emulate_mouse_from_touch=true", project)

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

    def test_app_review_information_covers_every_apple_question(self):
        notes = (ROOT / "fastlane/metadata/review_information/notes.txt").read_text(
            encoding="utf-8"
        )
        fastfile = (ROOT / "fastlane/Fastfile").read_text(encoding="utf-8")

        for heading in (
            "1. Screen recording",
            "2. Purpose and target audience",
            "3. Setup and access",
            "4. External services",
            "5. Regional differences",
            "6. Regulated industry and third-party material",
        ):
            self.assertIn(heading, notes)
        notes_lower = notes.lower()
        self.assertLessEqual(len(notes.encode("utf-8")), 4000)
        for statement in (
            "no account",
            "no in-app purchases",
            "no user-generated content",
            "ricagames",
            "same worldwide",
        ):
            self.assertIn(statement, notes_lower)

        self.assertIn("File.read", fastfile)
        self.assertNotIn("PlayTable nao exige login.", fastfile)

    def test_ios_network_permissions_are_declared(self):
        preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        export_script = (ROOT / "scripts/ios_export.sh").read_text(encoding="utf-8")
        self.assertIn("application/additional_plist_content=", preset)
        self.assertIn("NSLocalNetworkUsageDescription", preset)
        self.assertIn("NSLocalNetworkUsageDescription", export_script)
        self.assertIn("InfoPlist.strings", export_script)
        for unused_key in (
            "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSPhotoLibraryUsageDescription",
        ):
            self.assertIn(unused_key, export_script)

    def test_store_sources_are_real_localized_captures(self):
        source_root = ROOT / "screenshots" / "store"
        locales = ("pt-BR", "en-US", "es-ES")
        source_hashes = {}

        for locale in locales:
            for index in (1, 2, 3):
                source = source_root / locale / f"{index:02d}.png"
                self.assertTrue(source.is_file(), source)
                data = source.read_bytes()
                self.assertGreater(len(data), 5000, source)
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n", source)
                width, height = struct.unpack(">II", data[16:24])
                self.assertEqual((width, height), (720, 1280), source)
                source_hashes[(locale, index)] = hashlib.sha256(data).hexdigest()

        for index in (1, 2, 3):
            self.assertNotEqual(
                source_hashes[("pt-BR", index)],
                source_hashes[("en-US", index)],
                f"Portuguese and English source {index:02d} are identical",
            )
            self.assertNotEqual(
                source_hashes[("pt-BR", index)],
                source_hashes[("es-ES", index)],
                f"Portuguese and Spanish source {index:02d} are identical",
            )

        screenshot_script = (ROOT / "scripts/ios_store_screenshots.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("screenshots/store", screenshot_script)
        self.assertIn("shasum", screenshot_script)

    def test_generated_store_screenshots_are_not_copied_between_locales(self):
        reference = ROOT / "fastlane/screenshots/pt-BR/iPhone 6.5-1.png"
        reference_hash = hashlib.sha256(reference.read_bytes()).hexdigest()
        for locale in ("en-US", "es-ES"):
            candidate = ROOT / f"fastlane/screenshots/{locale}/iPhone 6.5-1.png"
            self.assertNotEqual(
                reference_hash,
                hashlib.sha256(candidate.read_bytes()).hexdigest(),
                f"{locale} screenshot was copied from pt-BR",
            )

    def test_physical_qa_is_a_release_gate(self):
        checklist = ROOT / "docs/app-store-connect/physical-device-qa.md"
        workflow = (ROOT / ".github/workflows/release-appstore.yml").read_text(
            encoding="utf-8"
        )
        self.assertTrue(checklist.is_file())
        self.assertIn("IOS_REVIEW_RECORDING_REFERENCE", workflow)
        self.assertIn("physical", checklist.read_text(encoding="utf-8").lower())


if __name__ == "__main__":
    unittest.main()
