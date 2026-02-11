#!/bin/bash

# Configuration
SOURCE_DIR="/Users/leonardofigueiredo/Projetos Mobile/ratio-ios/Ratio/Ratio/Assets.xcassets"
DEST_DIR="/Users/leonardofigueiredo/Projetos Mobile/ratio-ios/Ratio/Ratio/Resources/Images"

echo "📂 Creating destination directory: $DEST_DIR"
mkdir -p "$DEST_DIR"

# List of services to copy
SERVICES=(
    "netflix"
    "prime video"
    "spotify"
    "amazon prime"
    "disney+"
    "max"
    "youtube premium"
    "apple music"
    "apple one"
    "icloud+"
    "google one"
    "deezer"
    "globoplay"
    "paramount+"
    "star+"
    "chatgpt"
    "microsoft 365"
    "adobe cc"
    "canva pro"
)

echo "🚀 Starting backup..."

count=0
for service in "${SERVICES[@]}"; do
    # Path to the image inside the imageset
    # The structure is Assets.xcassets/PopularSubscription/servicename.imageset/servicename.png
    SRC_FILE="$SOURCE_DIR/PopularSubscription/$service.imageset/$service.png"
    DEST_FILE="$DEST_DIR/$service.png"
    
    if [ -f "$SRC_FILE" ]; then
        cp "$SRC_FILE" "$DEST_FILE"
        echo "✅ Copied $service.png"
        ((count++))
    else
        echo "⚠️  Missing source file for $service"
    fi
done

echo "🏁 Backup complete! Copied $count images to $DEST_DIR"
