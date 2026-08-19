#!/usr/bin/env python3
"""
Test Suite: Internationalization (i18n) & Translations
Tests CSV integrity, coverage for all 3 supported locales (pt_BR, en, es),
and MockLocaleManager behavior.
"""
import unittest
import csv
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
I18N_CSV_PATH = os.path.join(PROJECT_ROOT, "core", "i18n", "translations.csv")

class MockLocaleManager:
    """Mock of LocaleManager GDScript singleton"""
    SUPPORTED_LOCALES = [
        {"code": "pt_BR", "name": "Português (BR)"},
        {"code": "en", "name": "English"},
        {"code": "es", "name": "Español"}
    ]

    def __init__(self, save_storage=None, system_locale="en_US"):
        self.save_storage = save_storage if save_storage is not None else {}
        self.system_locale = system_locale
        self.current_locale = "pt_BR"
        self._init_locale()

    def _init_locale(self):
        saved = self.save_storage.get("locale", "")
        if saved and self._is_supported(saved):
            self.set_locale(saved)
        else:
            matched = self._match_supported(self.system_locale)
            self.set_locale(matched)

    def _is_supported(self, code):
        return any(loc["code"] == code for loc in self.SUPPORTED_LOCALES)

    def _match_supported(self, sys_locale):
        lower = sys_locale.lower()
        if lower.startswith("pt"):
            return "pt_BR"
        elif lower.startswith("es"):
            return "es"
        elif lower.startswith("en"):
            return "en"
        return "pt_BR"

    def set_locale(self, code):
        self.current_locale = code
        self.save_storage["locale"] = code

    def cycle_locale(self):
        codes = [loc["code"] for loc in self.SUPPORTED_LOCALES]
        idx = codes.index(self.current_locale)
        next_code = codes[(idx + 1) % len(codes)]
        self.set_locale(next_code)
        return next_code


class TestI18n(unittest.TestCase):

    def test_translations_csv_exists_and_valid(self):
        self.assertTrue(os.path.isfile(I18N_CSV_PATH), "translations.csv not found")

        with open(I18N_CSV_PATH, mode='r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            headers = reader.fieldnames
            self.assertEqual(headers, ['id', 'pt_BR', 'en', 'es'])

            rows = list(reader)
            self.assertGreater(len(rows), 20, "Should have translations for menus, games and common strings")

            keys = set()
            for r in rows:
                key_id = r['id']
                self.assertTrue(key_id, "Key ID must not be empty")
                self.assertNotIn(key_id, keys, f"Duplicate translation key found: {key_id}")
                keys.add(key_id)

                self.assertTrue(len(r['pt_BR'].strip()) > 0, f"Missing pt_BR translation for {key_id}")
                self.assertTrue(len(r['en'].strip()) > 0, f"Missing en translation for {key_id}")
                self.assertTrue(len(r['es'].strip()) > 0, f"Missing es translation for {key_id}")

            # Verify crucial keys
            self.assertIn("APP_NAME", keys)
            self.assertIn("APP_TITLE", keys)
            self.assertIn("APP_SUBTITLE", keys)
            self.assertIn("MENU_BOARD_GAMES", keys)
            self.assertIn("MENU_CARD_GAMES", keys)
            self.assertIn("BTN_BACK", keys)
            self.assertIn("BTN_LANGUAGE", keys)

    def test_locale_manager_default_system_matching(self):
        # Match PT
        lm_pt = MockLocaleManager(system_locale="pt_BR")
        self.assertEqual(lm_pt.current_locale, "pt_BR")

        # Match EN
        lm_en = MockLocaleManager(system_locale="en_US")
        self.assertEqual(lm_en.current_locale, "en")

        # Match ES
        lm_es = MockLocaleManager(system_locale="es_AR")
        self.assertEqual(lm_es.current_locale, "es")

        # Fallback to pt_BR
        lm_other = MockLocaleManager(system_locale="ja_JP")
        self.assertEqual(lm_other.current_locale, "pt_BR")

    def test_locale_manager_cycle_and_persistence(self):
        storage = {}
        lm = MockLocaleManager(save_storage=storage, system_locale="pt_BR")
        self.assertEqual(lm.current_locale, "pt_BR")

        # Cycle to English
        next_loc = lm.cycle_locale()
        self.assertEqual(next_loc, "en")
        self.assertEqual(storage["locale"], "en")

        # Cycle to Spanish
        next_loc = lm.cycle_locale()
        self.assertEqual(next_loc, "es")
        self.assertEqual(storage["locale"], "es")

        # Cycle back to Portuguese
        next_loc = lm.cycle_locale()
        self.assertEqual(next_loc, "pt_BR")
        self.assertEqual(storage["locale"], "pt_BR")

        # New session honors saved preference
        lm_restored = MockLocaleManager(save_storage=storage, system_locale="en_US")
        self.assertEqual(lm_restored.current_locale, "pt_BR")


if __name__ == '__main__':
    unittest.main()
