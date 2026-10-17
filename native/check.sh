#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bb-watch-check.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT
trap 'exit 1' HUP INT TERM

run() {
    name=$1
    shift
    log="$TMP_DIR/$name.log"
    printf '\n== %s ==\n' "$name"
    if "$@" >"$log" 2>&1; then
        tail -n 6 "$log"
    else
        tail -n 60 "$log"
        return 1
    fi
}

run swift-package-tests swift test --package-path .

run client-contract-compile swiftc -swift-version 6 \
    Sources/BBWatch/BBClient.swift Checks/BBClientContractCheck.swift \
    -o "$TMP_DIR/BBClientContractCheck"
run client-contract-check "$TMP_DIR/BBClientContractCheck"

run chat-list-compile swiftc -swift-version 6 \
    Sources/BBWatch/BBClient.swift Sources/BBWatch/ChatList.swift Checks/ChatListCheck.swift \
    -o "$TMP_DIR/ChatListCheck"
run chat-list-check "$TMP_DIR/ChatListCheck"

run glance-presentation-compile swiftc -swift-version 6 \
    Sources/BBWatchCore/DurableStore.swift Sources/BBWatch/BBClient.swift \
    Sources/BBWatch/GlancePresentation.swift Checks/GlancePresentationCheck.swift \
    -o "$TMP_DIR/GlancePresentationCheck"
run glance-presentation-check "$TMP_DIR/GlancePresentationCheck"

run audio-check-compile swiftc -swift-version 6 \
    Sources/BBWatchCore/DurableStore.swift Sources/BBWatch/AudioWriter.swift \
    Checks/AudioCheckpointCheck.swift -o "$TMP_DIR/AudioCheckpointCheck"
run audio-check "$TMP_DIR/AudioCheckpointCheck"

run transcription-compile swiftc -swift-version 6 \
    Sources/BBWatchCore/DurableStore.swift Sources/BBWatch/BBClient.swift \
    Sources/BBWatch/Diagnostics.swift Sources/BBWatch/TranscriptionPipeline.swift \
    Checks/TranscriptionWireFixture.swift Checks/TranscriptionCheck.swift \
    -o "$TMP_DIR/TranscriptionCheck"
run transcription-check "$TMP_DIR/TranscriptionCheck"

run diagnostics-compile swiftc -swift-version 6 \
    Sources/BBWatch/Diagnostics.swift Checks/DiagnosticsCheck.swift \
    -o "$TMP_DIR/DiagnosticsCheck"
run diagnostics-check "$TMP_DIR/DiagnosticsCheck"

run strict-watchsim-typecheck xcrun --sdk watchsimulator swiftc -typecheck \
    -swift-version 6 -target arm64-apple-watchos26.0-simulator \
    Sources/BBWatch/*.swift Sources/BBWatchCore/DurableStore.swift

run xcodegen xcodegen generate --spec project.yml

run watchos-sdk-build xcodebuild -project BBWatch.xcodeproj -target BBWatch \
    -sdk watchos -configuration Debug \
    CONFIGURATION_BUILD_DIR="$PWD/.build-xcode-watchos" \
    CODE_SIGNING_ALLOWED=NO build

run watchsimulator-sdk-build xcodebuild -project BBWatch.xcodeproj -target BBWatch \
    -sdk watchsimulator -configuration Debug \
    CONFIGURATION_BUILD_DIR="$PWD/.build-xcode-watchsimulator" \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build

printf '\nAll BB Watch checks passed.\n'
