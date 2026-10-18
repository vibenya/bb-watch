# Voice notes on the wrist — references and direction

18 October 2026. Research for the user's revised direction. Third-party designs
are linked for reference, not redistributed assets or verified watchOS code.

## Shortlist

| Reference | Useful part | Avoid copying |
|---|---|---|
| [Interaction Design Collection — AI Assistants, Shimon Bar Yacov, Behance](https://www.behance.net/gallery/214559277/Interaction-Design-Collection-AI-Assistants) | 2025 collection explicitly devoted to assistant spheres/orbs; strongest dedicated orb-motion reference | Author describes Cinema4D/After Effects work, not real-time watchOS components |
| [OPPO Breeno Voice Assistant — Flatwhite Motion, Behance](https://www.behance.net/gallery/158028057/OPPO-Breeno-Voice-Assistant) | Voice-assistant motion identity with a warm, personal character; useful direction for expressive feedback | A 3D promotional motion production, not a watch interaction contract |
| [Voice Note Recorder — Sayali Bendre / DesignBoat, Behance](https://www.behance.net/gallery/82867473/Voice-Note-Recorder-Apple-watch) | Large red central microphone as the clear entry point to capture; visually inspected | Start Recording text, separate paged library and old watch styling; this is a 2019 concept |
| [Recorder — Neha Gupta, Behance](https://www.behance.net/gallery/109818603/Recorder-Apple-Watch-App-Design) | Very sparse recording surface and legible recording rows; visually inspected | Giant elapsed-time treatment, paging and share controls; this is a 2020 concept |
| [Silly & Cristal Voice Assistant — Hicy Won, Behance](https://www.behance.net/gallery/114494633/Silly-Cristal-Voice-Assistant) | Luminous voice form on black; motion reference, visually inspected in browser | Full-screen assistant persona and dialogue; not a watch recorder implementation |
| [Siri HomePod Animation — Michael Steeber, Dribbble](https://dribbble.com/shots/3556417-Siri-HomePod-Animation) | Author's remake of the Siri orb; reference for a soft, internally moving voice object | Not watchOS code: the author identifies After Effects; native performance is unproven |
| [Just Press Record — official product](https://www.openplanetsoftware.com/just-press-record/) | A shipped one-tap watch capture reference; compare the recording job, not only artwork | Its sync/transcription service and navigation are not our plugin contract |
| [Apple Voice Memos on Watch — official guide](https://support.apple.com/guide/watch/voice-memos-apd441786282/26/watchos/26) | Native capture and recording-list behavior; the documented watch flow uses Record then Stop | Do not claim the iPhone Pause/Resume workflow is the documented watch workflow |

These are visual studies, not current HIG authority. The watch-layout concepts
are from 2019/2020; the orb collection is from 2025. The most useful combination
is the red capture focus from Voice Note Recorder, restrained
voice-reactive light inspired by the orb-motion references, and the native simplicity
of Voice Memos / Just Press Record.

## Button recommendation

- Idle: a stable red circular control, still and unmistakably tappable.
- Real capture: a soft red/coral halo or restrained deformation around that
  same control, driven by measured microphone amplitude with smoothing.
- Quiet input: the form settles; no unrelated equalizer dances continually.
- Pause: motion stops; Resume remains an explicit familiar control.
- Send: retain explicit transmission; do not make Stop/Pause silently send.
- Dimmed/background or Reduce Motion: keep truthful static capture feedback;
  stop nonessential animation. No whole-screen rainbow or edge glow is needed.
- Start/pause feedback follows actual microphone state, not an optimistic tap.

This describes a custom recording control inspired by voice assistants, not an
embedded Siri interface or an on-watch agent-thinking display. Do not animate
desktop routing/transcription as though the microphone were still listening.

## Library findings

| Candidate | Verified source facts | Recommendation |
|---|---|---|
| [SiriWaveView](https://github.com/alfianlosari/SiriWaveView) | SwiftUI, MIT; exposes microphone-power input for an iOS9-style waveform | Source reference for amplitude handling; not a modern orb, and no watch build was run |
| [FluidGradient](https://github.com/Cindori/FluidGradient) | MIT; CoreAnimation/SwiftUI layered blurred gradients; [manifest](https://raw.githubusercontent.com/Cindori/FluidGradient/main/Package.swift) names iOS/macOS | Visual/math reference only; do not present it as a ready watch component or infer battery behavior from desktop claims |
| [Pow](https://github.com/EmergeTools/Pow) | [Open watchOS compatibility issue](https://github.com/EmergeTools/Pow/issues/71) | Not selected for the watch; compatibility has not been established |
| Native [Canvas](https://developer.apple.com/documentation/swiftui/canvas) / [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview) | Apple's drawing and scheduled-update building blocks | Preferred small implementation candidate; actual watch compilation, frame cost and energy still need measurement |

No library was installed and no claim is made that a ready-to-use modern Siri
orb package has passed watchOS checks. Web/React orb components are not native
watch dependencies.
