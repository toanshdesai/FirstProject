#!/bin/bash
# Create GitHub release with DMG installer

set -e

# Configuration
REPO_OWNER="toanshdesai"
REPO_NAME="ToDo-App"
VERSION="v1.0.0"
RELEASE_NAME="TODO App v1.0.0"
DMG_FILE="dist/TODO-Installer.dmg"

echo "📦 Creating GitHub Release for TODO App"
echo ""

# Check if DMG exists
if [ ! -f "$DMG_FILE" ]; then
    echo "❌ Error: DMG file not found at $DMG_FILE"
    echo "   Please run ./create_dmg.sh first"
    exit 1
fi

# Check if token is provided
if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  GitHub Personal Access Token required"
    echo ""
    echo "To create a token:"
    echo "  1. Go to https://github.com/settings/tokens"
    echo "  2. Click 'Generate new token' → 'Generate new token (classic)'"
    echo "  3. Give it a name (e.g., 'TODO App Release')"
    echo "  4. Select scope: 'repo' (Full control of private repositories)"
    echo "  5. Click 'Generate token'"
    echo "  6. Copy the token"
    echo ""
    echo "Then run:"
    echo "  export GITHUB_TOKEN=your_token_here"
    echo "  ./create_release.sh"
    echo ""
    exit 1
fi

echo "🏷️  Creating git tag: $VERSION"
git tag -a "$VERSION" -m "$RELEASE_NAME" 2>/dev/null || echo "Tag already exists"

echo "📤 Pushing tag to GitHub..."
git push origin "$VERSION" 2>/dev/null || echo "Tag already pushed"

echo ""
echo "🚀 Creating GitHub release..."

# Create release notes
RELEASE_NOTES="# TODO App - Desktop Task Manager

A clean, professional TODO application for macOS with priorities, due dates, and subtasks.

## 🎉 What's New in v1.0.0

- ✅ Add, complete, and delete tasks
- 🎯 Priority levels (High, Medium, Low)
- 📅 Due dates for tasks
- 📋 Subtasks for organizing complex work
- 🎨 Dark mode with GitHub-inspired colors
- 🖱️ Drag-and-drop to reorder tasks
- 📊 Sort by priority or due date
- 💾 Auto-saves to JSON

## 📥 Installation

### Option 1: DMG Installer (Recommended)
1. Download \`TODO-Installer.dmg\` below
2. Double-click to mount
3. Drag TODO.app to Applications
4. Launch from Launchpad or Spotlight

### Option 2: Direct Download
1. Download \`TODO.app.zip\` below
2. Extract and run

## 🔒 macOS Security Note

First time opening the app:
- Right-click TODO.app → Select \"Open\"
- Click \"Open\" in the security dialog
- After this, you can double-click normally

## 📝 Requirements

- macOS 10.12 or later
- No Python installation needed

## 🐛 Report Issues

Found a bug? [Create an issue](https://github.com/$REPO_OWNER/$REPO_NAME/issues)
"

# Create the release via GitHub API
RESPONSE=$(curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases" \
  -d @- << EOF
{
  "tag_name": "$VERSION",
  "name": "$RELEASE_NAME",
  "body": $(echo "$RELEASE_NOTES" | jq -Rs .),
  "draft": false,
  "prerelease": false
}
EOF
)

# Get upload URL and release ID from response
UPLOAD_URL=$(echo "$RESPONSE" | grep -o '"upload_url": "[^"]*' | cut -d'"' -f4 | sed 's/{?name,label}//')
RELEASE_ID=$(echo "$RESPONSE" | grep -o '"id": [0-9]*' | head -1 | awk '{print $2}')

if [ -z "$UPLOAD_URL" ]; then
    echo "❌ Failed to create release. Response:"
    echo "$RESPONSE"
    exit 1
fi

echo "✅ Release created successfully!"
echo ""
echo "📎 Uploading DMG installer..."

# Upload the DMG file
UPLOAD_RESPONSE=$(curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/x-apple-diskimage" \
  -H "Accept: application/vnd.github.v3+json" \
  --data-binary @"$DMG_FILE" \
  "${UPLOAD_URL}?name=TODO-Installer.dmg&label=TODO%20Installer%20for%20macOS")

# Check if upload was successful
if echo "$UPLOAD_RESPONSE" | grep -q '"state": "uploaded"'; then
    echo "✅ DMG uploaded successfully!"
else
    echo "⚠️  DMG upload may have failed. Response:"
    echo "$UPLOAD_RESPONSE"
fi

# Optional: Also create a ZIP of the app
echo ""
echo "📦 Creating ZIP archive..."
if [ ! -f "dist/TODO.app.zip" ]; then
    cd dist
    zip -r -q TODO.app.zip TODO.app
    cd ..
fi

echo "📎 Uploading ZIP archive..."
ZIP_RESPONSE=$(curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/zip" \
  -H "Accept: application/vnd.github.v3+json" \
  --data-binary @"dist/TODO.app.zip" \
  "${UPLOAD_URL}?name=TODO.app.zip&label=TODO%20App%20(ZIP)")

if echo "$ZIP_RESPONSE" | grep -q '"state": "uploaded"'; then
    echo "✅ ZIP uploaded successfully!"
else
    echo "⚠️  ZIP upload may have failed"
fi

echo ""
echo "🎉 Release complete!"
echo ""
echo "🔗 View your release at:"
echo "   https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$VERSION"
echo ""
