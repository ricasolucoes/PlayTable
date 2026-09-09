import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import play_store_publish as publisher


class PublisherTests(unittest.TestCase):
    def setUp(self):
        self.service = MagicMock()
        self.edits = self.service.edits.return_value
        self.edits.insert.return_value.execute.return_value = {"id": "test-edit"}
        self.patch = patch.object(publisher, "get_publisher_service", return_value=self.service)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def publish(self, **kwargs):
        with contextlib.redirect_stdout(io.StringIO()):
            publisher.publish("org.playtable.app", **kwargs)

    def test_verify_only_validates_then_deletes_without_commit(self):
        self.publish(verify_only=True)
        self.edits.validate.assert_called_once_with(packageName="org.playtable.app", editId="test-edit")
        self.edits.delete.assert_called_once()
        self.edits.commit.assert_not_called()

    def test_validation_failure_aborts_publication(self):
        self.edits.validate.return_value.execute.side_effect = RuntimeError("invalid release")
        with self.assertRaises(RuntimeError):
            self.publish()
        self.edits.commit.assert_not_called()
        self.edits.delete.assert_called_once()

    def test_metadata_failure_aborts_publication(self):
        with tempfile.TemporaryDirectory() as folder:
            locale = Path(folder) / "pt-BR"
            locale.mkdir()
            (locale / "title.txt").write_text("PlayTable")
            self.edits.listings.return_value.update.return_value.execute.side_effect = RuntimeError("invalid listing")
            with self.assertRaises(RuntimeError):
                self.publish(metadata_dir=folder)
        self.edits.commit.assert_not_called()
        self.edits.delete.assert_called_once()

    def test_named_release_uses_uploaded_version_code(self):
        with tempfile.TemporaryDirectory() as folder:
            bundle = Path(folder) / "test.aab"
            bundle.write_bytes(b"test")
            upload_mock = self.edits.bundles.return_value.upload.return_value
            upload_mock.next_chunk.return_value = (None, {"versionCode": 13})
            upload_mock.execute.return_value = {"versionCode": 13}
            self.publish(aab_path=str(bundle), release_name="0.8.0")
        body = self.edits.tracks.return_value.update.call_args.kwargs["body"]
        self.assertEqual(body["releases"][0]["name"], "0.8.0")
        self.assertEqual(body["releases"][0]["versionCodes"], ["13"])
        self.edits.commit.assert_called_once()

    def test_version_notes_override_default(self):
        with tempfile.TemporaryDirectory() as folder:
            notes = Path(folder) / "pt-BR" / "changelogs"
            notes.mkdir(parents=True)
            (notes / "default.txt").write_text("old")
            (notes / "13.txt").write_text("new")
            self.assertEqual(publisher.get_release_notes(Path(folder), 13), [{"language": "pt-BR", "text": "new"}])

if __name__ == "__main__":
    unittest.main()
