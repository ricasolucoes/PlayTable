#!/bin/bash
# Generate Signed APK Script

echo "=> Iniciando configuração do Android SDK e Build do Godot..."

export JAVA_HOME="/Users/sierra/Dev/Jogos/jdk-17.0.2.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p build/android

if [ ! -f "release.keystore" ]; then
    echo "=> Gerando release.keystore..."
    keytool -genkey -v -keystore release.keystore -alias alias_name -keyalg RSA -keysize 2048 -validity 10000 -storepass REDACTED_ROTATED_KEY -keypass REDACTED_ROTATED_KEY -dname "CN=GSD, OU=Games, O=Dev, L=BR, S=BR, C=BR"
fi

echo "=> Exportando APK pelo Godot (Headless)..."
./Godot.app/Contents/MacOS/Godot -ApplePersistenceIgnoreState YES --headless --export-release "Android" build/android/JogosDeMesaOffline.apk

echo "=> Build Concluída! APK Assinado salvo em build/android/JogosDeMesaOffline.apk"
