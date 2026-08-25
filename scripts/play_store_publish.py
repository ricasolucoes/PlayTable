#!/usr/bin/env python3
"""
Google Play Store Automated Publisher
Automates uploading Android App Bundles (.aab) and syncing localized metadata to Google Play Console.
Uses Google Play Android Developer API v3 with Service Account credentials.
"""

import argparse
import os
import sys
import json
from pathlib import Path
import warnings

warnings.filterwarnings("ignore")

try:
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload
    from google.oauth2 import service_account
except ImportError:
    print("❌ Dependências ausentes. Execute:")
    print("   pip3 install --user google-api-python-client google-auth google-auth-httplib2")
    sys.exit(1)

DEFAULT_KEY_PATH = "/Users/sierra/Dev/keystores/play-store-api-key.json"

def get_publisher_service(key_path: str):
    if not os.path.exists(key_path):
        raise FileNotFoundError(f"Arquivo de credenciais JSON não encontrado em: {key_path}")
    
    creds = service_account.Credentials.from_service_account_file(
        key_path,
        scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    return build("androidpublisher", "v3", credentials=creds)

def sync_metadata(service, package_name: str, edit_id: str, metadata_dir: Path):
    if not metadata_dir.is_dir():
        print(f"⚠️  Diretório de metadados não encontrado em {metadata_dir}. Pulando metadados.")
        return

    print(f"📖 Sincronizando metadados multilíngues de: {metadata_dir}")
    for locale_dir in sorted(metadata_dir.iterdir()):
        if not locale_dir.is_dir() or locale_dir.name.startswith("."):
            continue
        
        locale = locale_dir.name
        title_file = locale_dir / "title.txt"
        short_file = locale_dir / "short_description.txt"
        full_file = locale_dir / "full_description.txt"

        title = title_file.read_text(encoding="utf-8").strip() if title_file.exists() else None
        short_desc = short_file.read_text(encoding="utf-8").strip() if short_file.exists() else None
        full_desc = full_file.read_text(encoding="utf-8").strip() if full_file.exists() else None

        if not (title or short_desc or full_desc):
            continue

        listing_body = {}
        if title:
            listing_body["title"] = title
        if short_desc:
            listing_body["shortDescription"] = short_desc
        if full_desc:
            listing_body["fullDescription"] = full_desc

        try:
            service.edits().listings().update(
                packageName=package_name,
                editId=edit_id,
                language=locale,
                body=listing_body
            ).execute()
            print(f"   ✓ Metadados atualizados para [{locale}]")
        except Exception as e:
            print(f"   ⚠️  Aviso ao atualizar idioma [{locale}]: {e}")

def get_release_notes(metadata_dir: Path, version_code: int):
    notes = []
    if not metadata_dir or not metadata_dir.is_dir():
        return notes

    for locale_dir in sorted(metadata_dir.iterdir()):
        if not locale_dir.is_dir() or locale_dir.name.startswith("."):
            continue
        
        locale = locale_dir.name
        changelog_file = locale_dir / "changelogs" / f"{version_code}.txt"
        default_changelog = locale_dir / "changelogs" / "default.txt"

        content = None
        if changelog_file.exists():
            content = changelog_file.read_text(encoding="utf-8").strip()
        elif default_changelog.exists():
            content = default_changelog.read_text(encoding="utf-8").strip()

        if content:
            notes.append({
                "language": locale,
                "text": content
            })

    return notes

def publish(package_name: str, aab_path: str = None, track: str = "production",
            metadata_dir: str = None, key_path: str = DEFAULT_KEY_PATH,
            release_status: str = "completed", verify_only: bool = False):
    
    print(f"\n=======================================================")
    print(f"🚀 Google Play Publisher :: {package_name}")
    print(f"=======================================================")
    print(f"• Pacote:          {package_name}")
    print(f"• Faixa (Track):   {track}")
    print(f"• Status:          {release_status}")
    print(f"• Chave API:       {key_path}")
    if aab_path:
        print(f"• AAB:             {aab_path}")
    print(f"-------------------------------------------------------")

    service = get_publisher_service(key_path)

    # 1. Iniciar Sessão de Edição
    print("=> Iniciando sessão de edição no Google Play Developer API...")
    edit_request = service.edits().insert(packageName=package_name, body={})
    edit = edit_request.execute()
    edit_id = edit["id"]
    print(f"   ✓ Sessão de edição aberta: ID {edit_id}")

    try:
        version_code = None

        # 2. Upload do AAB se fornecido
        if aab_path:
            if not os.path.exists(aab_path):
                raise FileNotFoundError(f"Arquivo AAB não encontrado: {aab_path}")

            file_size_mb = os.path.getsize(aab_path) / (1024 * 1024)
            print(f"=> Fazendo upload do App Bundle ({file_size_mb:.2f} MB)...")
            
            media = MediaFileUpload(
                aab_path,
                mimetype="application/octet-stream",
                resumable=True
            )

            bundle_response = service.edits().bundles().upload(
                packageName=package_name,
                editId=edit_id,
                media_body=media
            ).execute()

            version_code = bundle_response.get("versionCode")
            print(f"   ✓ AAB enviado com sucesso! Versão (versionCode): {version_code}")

        # 3. Sincronizar metadados se diretório fornecido
        if metadata_dir:
            sync_metadata(service, package_name, edit_id, Path(metadata_dir))

        # 4. Atualizar faixa de lançamento (Track) se houver AAB
        if version_code:
            print(f"=> Atualizando faixa de lançamento '{track}'...")
            
            release_notes = []
            if metadata_dir:
                release_notes = get_release_notes(Path(metadata_dir), version_code)

            release_body = {
                "name": f"Release {version_code}",
                "versionCodes": [str(version_code)],
                "status": release_status
            }
            if release_notes:
                release_body["releaseNotes"] = release_notes

            track_body = {
                "track": track,
                "releases": [release_body]
            }

            service.edits().tracks().update(
                packageName=package_name,
                editId=edit_id,
                track=track,
                body=track_body
            ).execute()
            print(f"   ✓ Faixa '{track}' configurada com a versão {version_code}")

        # 5. Validar / Comitar Edição
        if verify_only:
            print("=> Modo de verificação (--verify-only): Cancelando edição sem publicar.")
            service.edits().delete(packageName=package_name, editId=edit_id).execute()
            print("✅ Conexão, permissões e validação concluídas com sucesso!")
        else:
            print("=> Comitando alterações para o Google Play Console...")
            commit_response = service.edits().commit(
                packageName=package_name,
                editId=edit_id
            ).execute()
            print(f"✅ Publicação efetuada com sucesso no Google Play! Edit ID: {commit_response.get('id', edit_id)}")

    except Exception as err:
        print(f"\n❌ Erro durante o processo de edição: {err}")
        try:
            service.edits().delete(packageName=package_name, editId=edit_id).execute()
            print("   (Sessão de edição cancelada)")
        except Exception:
            pass
        raise err

def main():
    parser = argparse.ArgumentParser(description="Google Play Store automated deployment tool.")
    parser.add_argument("--package", required=True, help="Application Package Name (e.g. org.playtable.app)")
    parser.add_argument("--aab", help="Path to signed .aab file to upload")
    parser.add_argument("--track", default="production", choices=["production", "beta", "alpha", "internal"],
                        help="Release track (default: production)")
    parser.add_argument("--metadata-dir", help="Path to fastlane metadata directory (e.g. fastlane/metadata/android)")
    parser.add_argument("--key", default=DEFAULT_KEY_PATH, help=f"Path to Service Account JSON key (default: {DEFAULT_KEY_PATH})")
    parser.add_argument("--status", default="completed", choices=["completed", "draft", "inProgress", "halted"],
                        help="Release status (default: completed)")
    parser.add_argument("--verify-only", action="store_true", help="Authenticate and open/close edit session without committing")

    args = parser.parse_args()

    try:
        publish(
            package_name=args.package,
            aab_path=args.aab,
            track=args.track,
            metadata_dir=args.metadata_dir,
            key_path=args.key,
            release_status=args.status,
            verify_only=args.verify_only
        )
    except Exception as e:
        sys.exit(1)

if __name__ == "__main__":
    main()
