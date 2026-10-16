# BB Watch asset sources

Both assets below are copied from the installed BB application and preserve the supplied artwork. The header logo remains an SVG vector; the watch icon is the 1024 px native representation extracted from the application's ICNS, not enlarged from its web 512 px icon.

| Asset | Source | Use |
|---|---|---|
| `Sources/BBWatch/Assets.xcassets/BBLogo.imageset/BBLogo.svg` | `/Applications/bb.app/Contents/Resources/app.asar.unpacked/node_modules/bb-app/app/dist/assets/bb-logo-BA9hTSLL.svg` | Transparent graphite BB mark for the header. The UI may render it as a white template on the dark navigation background. |
| `Sources/BBWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | `/Applications/bb.app/Contents/Resources/icon.icns`, extracted with `iconutil -c iconset`; uses `icon_512x512@2x.png` (1024 × 1024). | Official BB app icon for watchOS. |

The original SVG and extracted 1024 × 1024 PNG were visually inspected before use. The asset catalog build should confirm Xcode accepts the SVG's features.

## Public repository

The artwork files and screenshots are excluded from Git because redistribution rights have not been established. This provenance records local development use only. Supply your own licensed SVG and 1024px PNG at the catalog paths before building. MIT does not grant rights to BB artwork or trademarks.
