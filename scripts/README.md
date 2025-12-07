AppIcon.appiconset

This folder contains the macOS app icons used by the SwiftBmo project. The Contents.json already lists the following filenames which Xcode expects:

- icon_16x16.png
- icon_16x16@2x.png
- icon_32x32.png
- icon_32x32@2x.png
- icon_128x128.png
- icon_128x128@2x.png
- icon_256x256.png
- icon_256x256@2x.png
- icon_512x512.png
- icon_512x512@2x.png

How to generate icons locally

1) Preferred: provide a single high-resolution source (1024x1024) PNG and run the script from the repo root:

   ./scripts/generate_appicon_placeholders.sh path/to/source.png

2) If you don't have a source, the script will create simple colored placeholders:

   ./scripts/generate_appicon_placeholders.sh

Notes

- After generating files, open Xcode and select the asset catalog; Xcode should automatically detect the images. If not, refresh the asset catalog or re-add the images.
- For production, replace placeholders with carefully-designed icons following Apple's Human Interface Guidelines.
