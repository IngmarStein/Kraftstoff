#!/bin/sh

# Create a custom keychain
security create-keychain -p ci mac-build.keychain

# Make the custom keychain default, so xcodebuild will use it for signing
security default-keychain -s mac-build.keychain

# Unlock the keychain
security unlock-keychain -p ci mac-build.keychain

# Set keychain timeout to 1 hour for long builds
# see http://www.egeek.me/2013/02/23/jenkins-and-xcode-user-interaction-is-not-allowed/
security set-keychain-settings -t 3600 -l ~/Library/Keychains/mac-build.keychain

# Add certificates to keychain and allow codesign to access them
security import ./scripts/certs/apple.cer -k ~/Library/Keychains/mac-build.keychain -T /usr/bin/codesign
security import ./scripts/certs/dist.cer -k ~/Library/Keychains/mac-build.keychain -T /usr/bin/codesign
security import ./scripts/certs/dist.p12 -k ~/Library/Keychains/mac-build.keychain -P "$KEY_PASSWORD" -T /usr/bin/codesign

# Required since macOS Sierra (see https://openradar.appspot.com/28524119)
security set-key-partition-list -S "apple-tool:,apple:" -k ci ~/Library/Keychains/mac-build.keychain

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
for PROVISION in ./scripts/profiles/*.*provision*
do
  UUID=`/usr/libexec/PlistBuddy -c 'Print :UUID' /dev/stdin <<< $(security cms -D -i $PROVISION)`
  cp "$PROVISION" "$HOME/Library/MobileDevice/Provisioning Profiles/$UUID.${PROVISION##*.}"
done