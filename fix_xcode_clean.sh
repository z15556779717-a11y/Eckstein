#!/bin/bash

echo "=== Xcode Project Cleanup Script ==="
echo "This script will clean all Xcode caches and reset the project"
echo ""

# Change to project directory
cd "$(dirname "$0")"

echo "1. Killing Xcode if running..."
killall Xcode 2>/dev/null || true
sleep 2

echo "2. Removing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

echo "3. Removing module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/

echo "4. Clearing SPM caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/.swiftpm

echo "5. Cleaning project-specific files..."
rm -rf Eckstein/Eckstein.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
rm -rf Eckstein/Eckstein.xcodeproj/project.xcworkspace/xcuserdata/
rm -rf Eckstein/Eckstein.xcodeproj/xcuserdata/

echo "6. Removing build folder if exists..."
rm -rf build/
rm -rf .build/

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Open the project"
echo "3. Wait for 'Resolving Package Versions' to complete"
echo "4. If Supabase package is missing:"
echo "   - File → Add Package Dependencies"
echo "   - URL: https://github.com/supabase/supabase-swift"
echo "   - Version: Up to Next Major 2.0.0"
echo "5. Try building again"
echo ""
echo "If still having issues, try:"
echo "- Restart your Mac"
echo "- Delete Xcode and reinstall from App Store"