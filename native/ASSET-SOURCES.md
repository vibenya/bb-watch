# BB Watch asset sources

The header logo is copied from the installed BB application and preserves the supplied SVG artwork. The watch icon is the locally selected lime bracelet design generated using the official BB mark as a reference.

| Asset | Source | Use |
|---|---|---|
| `Sources/BBWatch/Assets.xcassets/BBLogo.imageset/BBLogo.svg` | `/Applications/bb.app/Contents/Resources/app.asar.unpacked/node_modules/bb-app/app/dist/assets/bb-logo-BA9hTSLL.svg` | Transparent graphite BB mark for the header. The UI may render it as a white template on the dark navigation background. |
| `Sources/BBWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | Local `output/imagegen/five-flat-variants/02-lime.png`, generated with built-in imagegen using the official BB icon as reference; resized to opaque 1024 × 1024 PNG. | User-selected lime background, black bb bracelet and violet silhouette arm for watchOS. |

The SVG and selected lime PNG were visually inspected before use. The app icon has no baked mask; watchOS applies its circular crop.

## Public repository

The artwork files and screenshots are excluded from Git because redistribution rights have not been established. This provenance records local development use only. Supply your own licensed SVG and 1024px PNG at the catalog paths before building. MIT does not grant rights to BB artwork or trademarks.
