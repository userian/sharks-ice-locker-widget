#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# Navigate to the root of the repository in Xcode Cloud.
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "=== Installing Flutter SDK (stable) for Xcode Cloud ==="
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi
export PATH="$PATH:$HOME/flutter/bin"

# Disable Swift Package Manager auto-migration so CocoaPods + Podfile run cleanly
flutter config --no-enable-swift-package-manager || true

# If ios/Runner.xcodeproj is not in the checkout yet, scaffold it and restore custom files
if [ ! -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
  echo "=== Scaffolding iOS Xcode project ==="
  mkdir -p /tmp/xccloud_backup
  cp -r lib test ios assets pubspec.yaml /tmp/xccloud_backup/
  flutter create . --org com.makeshiftlabs --project-name sharks_ice_locker_widget
  cp /tmp/xccloud_backup/pubspec.yaml pubspec.yaml
  cp -r /tmp/xccloud_backup/lib/* lib/
  cp -r /tmp/xccloud_backup/test/* test/
  cp -r /tmp/xccloud_backup/assets/* assets/
  rm -f test/widget_test.dart
  cp -r /tmp/xccloud_backup/ios/* ios/
  sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 16.0;/g' ios/Runner.xcodeproj/project.pbxproj
fi

echo "=== Pre-caching iOS artifacts & fetching pub dependencies ==="
flutter precache --ios
flutter pub get

BUILD_NUM="${CI_BUILD_NUMBER:-1}"
echo "=== Generating Flutter iOS release config (Build #$BUILD_NUM) ==="
flutter build ios --config-only --release --no-codesign --build-number="$BUILD_NUM"

echo "=== Installing CocoaPods & configuring LockerRoomWidgetExtension ==="
HOMEBREW_NO_AUTO_UPDATE=1
if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

cd ios
pod install

echo "=== Xcode Cloud post-clone setup complete ==="
exit 0
