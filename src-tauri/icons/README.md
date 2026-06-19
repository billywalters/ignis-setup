# App Icons

Tauri requires the following icon files to build. Replace the placeholders
with actual PNG/ICO files before building or releasing.

| File | Size | Used for |
|------|------|----------|
| `32x32.png` | 32×32 | Linux taskbar / small icon |
| `128x128.png` | 128×128 | Linux app launcher |
| `128x128@2x.png` | 256×256 | Linux HiDPI |
| `icon.icns` | multi-size | macOS (not needed for Linux-only builds) |
| `icon.ico` | multi-size | Windows (not needed for Linux-only builds) |

## Generating icons from a source image

If you have a 1024×1024 PNG source file, the Tauri CLI can generate all
required sizes automatically:

```bash
npm run tauri icon path/to/your-icon-1024.png
```

## Current status

The `.gitkeep` files in this directory are placeholders. The CI and release
workflows will fail until real icon files are provided.

Until you have a proper icon, you can use Tauri's default icon by running:

```bash
# Copy default Tauri icons as a starting point
curl -o 32x32.png https://github.com/tauri-apps/tauri/raw/dev/app-icon.png
# Then resize to the required dimensions with ImageMagick:
# convert app-icon.png -resize 32x32 32x32.png
# convert app-icon.png -resize 128x128 128x128.png
# etc.
```
