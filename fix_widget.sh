#!/bin/bash

# Quick fix script to clean widget build
echo "🔧 Cleaning widget build artifacts..."

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Brandon*

echo "✅ Cleaned derived data"
echo "📝 Next steps:"
echo "1. Open project in Xcode"
echo "2. Select each problematic file in Project Navigator"
echo "3. In File Inspector, uncheck 'Budget WidgetExtension' target"
echo "4. Files to fix:"
echo "   - Core/Services/CoreDataManager.swift"
echo "   - Core/Types/AppEnums.swift"
echo "   - Core/Types/SharedDataManager.swift"
echo "   - All other Core/ and Utils/ files"
echo "5. Build again"