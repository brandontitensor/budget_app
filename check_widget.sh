#!/bin/bash

echo "🔍 Checking widget target status..."

# Try building just to see current errors
echo "Building widget to check remaining issues..."
xcodebuild -project "Brandon's Budget.xcodeproj" -scheme "Budget WidgetExtension" -destination "platform=iOS Simulator,name=iPhone 16" build 2>&1 | grep -E "(SwiftCompile|failed)" | head -10

echo ""
echo "✅ Widget should only compile files in Widget/ directory"
echo "❌ If you see Core/ or Utils/ files above, remove them from widget target"