#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:$PATH"
SDK="$HOME/ios4sdk/iPhoneOS4.3.sdk"
APP=HabitsAudit
mkdir -p test-build/Payload/$APP.app
FILES=(src/*.m)
FILES=(${FILES:#src/main.m})
clang -DHABITS=1 -target armv7-apple-ios4.3 -isysroot "$SDK" -fobjc-runtime=ios-4.3 -fno-objc-arc -marm -O1 -g -Wall -Wno-deprecated-declarations -Isrc ${AUDIT_MAIN:-tests/device.m} $FILES -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework AudioToolbox -lobjc -o test-build/Payload/$APP.app/$APP
ldid -S test-build/Payload/$APP.app/$APP
cat > test-build/Payload/$APP.app/Info.plist <<PL
<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>$APP</string><key>CFBundleIdentifier</key><string>com.mshukla.$APP</string><key>CFBundleName</key><string>$APP</string><key>CFBundleDisplayName</key><string>$APP</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>1</string><key>CFBundlePackageType</key><string>APPL</string><key>MinimumOSVersion</key><string>4.3</string><key>LSRequiresIPhoneOS</key><true/><key>UIDeviceFamily</key><array><integer>1</integer></array></dict></plist>
PL
if test -f res/exercises.json; then cp res/exercises.json test-build/Payload/$APP.app/; fi
(cd test-build && zip -qr $APP.ipa Payload/$APP.app)
