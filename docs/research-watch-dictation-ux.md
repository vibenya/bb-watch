# watchOS voice/dictation UX research (reference apps, APIs, principles)

Date: 2026-10-16. Scope: desk research for the BB Watch redesign (record-first,
"status as magic", three horizontal pages). Every claim carries a source;
items marked **[unverified]** could not be confirmed from a primary source.

## A. Reference apps: concrete interaction details

### 1. Apple Voice Memos (watchOS 26)
- Flow is two taps: tap Record, tap Stop. No Pause, no Done, no title prompt on the watch; recordings sync to iPhone/iPad/Mac automatically. ([Apple Support](https://support.apple.com/guide/watch/voice-memos-apd441786282/watchos))
- Recording screen anatomy (Apple's own screenshot description): a **red Stop button centred**, **elapsed time below it**, the word **"Recording" top-right** as a status label. ([Apple Support, image alt text](https://support.apple.com/guide/watch/voice-memos-apd441786282/watchos))
- Initial screen is a single "Tap to Record" affordance; the end control is labelled "End". Playback has ±15 s skip and Delete. ([Apple World Today, Feb 2026](https://appleworld.today/2026/02/how-to-use-the-voice-memos-app-in-watchos-26/))
- Digital Crown is not used during recording in any source; a waveform on the watch is **[unverified]** (no primary source describes one on watchOS, unlike iOS).
- A design study notes the watch app deliberately drops the iPhone's pause/rewind/re-record features and proposes press-and-hold with pulsing red rings as "recording" feedback: a concept, not shipping behaviour. ([Arthur Jensen](https://www.arthurjensen.com/spring-2024-posts/designing-microinteractions))

### 2. Just Press Record (watch)
- "One tap to start, stop, pause and resume recording"; unlimited recording time; records in the background; "Record independently on Apple Watch and sync later". ([App Store](https://apps.apple.com/us/app/just-press-record/id1033342465?platform=appleWatch))
- Start from a complication with a single tap, from Siri, Shortcuts or the Action Button. ([App Store](https://apps.apple.com/us/app/just-press-record/id1033342465?platform=appleWatch))
- Pause is a downward swipe; the Crown adjusts playback volume only. ([MacStories](https://www.macstories.net/reviews/just-press-record-refreshes-its-ios-design-and-adds-powerful-features-to-its-watch-app/))
- Transcription happens off-watch (on iPhone) with synchronized text highlighting on playback. ([App Store](https://apps.apple.com/us/app/just-press-record/id1033342465?platform=appleWatch))

### 3. Drafts (watch)
- The main screen is one big button that launches system dictation; the draft is saved the moment you tap Done, no title, no confirmation. ([Birchtree](https://birchtree.me/blog/drafts-5-on-apple-watch-review/))
- A complication setting ("Auto-capture") opens straight into dictation. ([Drafts forum](https://forums.getdrafts.com/t/watch-tip-enable-auto-capture-to-launch-straight-to-dictation-from-the-watch-face/1960))
- Known weakness of system dictation: the app gets no partial text and dictation times out after ~1 minute of silence, losing text. This is the argument for owning the audio pipeline (as BB Watch does). ([Drafts forum](https://forums.getdrafts.com/t/alert-for-apple-watch-dictation-users/11358))

### 4. Whisper Memos (watch)
- "Raise your wrist, tap the complication, and start talking"; fully standalone on cellular watches; syncs later when offline. ([Whisper Memos KB](https://whispermemos.com/kb/getting-started/welcome))
- Action Button on Ultra can be bound to start a recording. ([MacSparky](https://www.macsparky.com/?p=15509)) **[secondary source]**

### 5. Apple Design Award watch apps
- **Gentler Streak** (ADA 2024 Social Impact winner; Apple Watch App of the Year 2022): a "friendlier" tone, one central visual (the Activity Path), HealthKit data rendered as simple charts; watch app rebuilt in 2024 for speed/battery. ([Apple Developer](https://developer.apple.com/news/?id=3m0ht22s), [BGR](https://bgr.com/tech/gentler-streak-non-tracked-workouts/))
- **Lumy** (ADA 2025 Delight and Fun finalist): "simple design, carefully curated color palette, and elegant widgets and Live Activities ... syncs beautifully with Apple Watch". ([ADA 2025](https://developer.apple.com/design/awards/2025/))
- **Tide Guide** (ADA 2026 Interaction finalist, watchOS): adopts Liquid Glass, custom animations, and "the app's palette is designed to match the color of the sky throughout the day". ([ADA 2026](https://developer.apple.com/design/awards/))
- **The Outsiders** (ADA 2026 Interaction finalist, iOS+watchOS, by Gentler Stories) and **Harvee** (ADA 2026 Social Impact, watchOS): one hero visualization / one avatar carries the whole state. ([ADA 2026](https://developer.apple.com/design/awards/))
- SmartGym was a 2024 Innovation finalist. ([Apple Newsroom](https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards/)) Specific watch-screen details for SmartGym, Structured, Dot and Streaks were **not verified** in this pass.

### 6. System "ambient status" surfaces
- HIG Workouts: "Use a distinct visual appearance to indicate an active workout ... the values update in real time ... further distinguish the metrics screen by using a unique layout." ([HIG](https://developer.apple.com/design/human-interface-guidelines/workouts))
- Live Activities in the Smart Stack: "only the most critical information should be shown"; states worth showing are progress, required action, and state changes; "Controls are best for live activities that need to be played, paused or resumed ... a workout, a timer, or a voice memo"; stick to **one** control. The compact view "appears at the bottom of the display" while using the watch. ([WWDC24 10098](https://developer.apple.com/videos/play/wwdc2024/10098/))
- Always On: "Keep important content legible and dim nonessential content"; "Maintain a consistent layout"; "Gracefully transition motion to a resting state". ([HIG Always On](https://developer.apple.com/design/human-interface-guidelines/always-on))
- watchOS 26 Liquid Glass on watch is "not much more than a re-skinning" with reflective edges, no new animations, and legibility problems for translucent text over bright backgrounds. ([MacStories](https://www.macstories.net/stories/watchos-26-the-macstories-review/2/))

## B. watchOS 26 SwiftUI APIs per pattern (name, min watchOS, doc)

Paging and backgrounds
- `TabViewStyle.verticalPage` / `.verticalPage(transitionStyle:)` (watchOS 10) — https://developer.apple.com/documentation/swiftui/tabviewstyle/verticalpage
- `containerBackground(_:for:)` with `.navigation` / `.tabView` placement (watchOS 10) — https://developer.apple.com/documentation/swiftui/view/containerbackground(_:for:)
- `navigationTransition(_:)` (watchOS 11) — https://developer.apple.com/documentation/swiftui/view/navigationtransition(_:)

Toolbars / glass
- `ToolbarItemPlacement.topBarLeading`, `.topBarTrailing`, `.bottomBar`, `.primaryAction` (scrolling button) — https://developer.apple.com/documentation/swiftui/toolbaritemplacement ; HIG: buttons in top corners or bottom corners stay visible over scrolling content — https://developer.apple.com/design/human-interface-guidelines/toolbars
- `glassEffect(_:in:)` (watchOS 26) — https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
- `safeAreaBar(edge:alignment:spacing:content:)` (watchOS 26) — https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)
- `navigationSubtitle(_:)` is **not** available on watchOS (iOS 26/macOS only).

Text animation
- `ContentTransition.numericText(countsDown:)` (watchOS 9) for timers/counters — https://developer.apple.com/documentation/swiftui/contenttransition/numerictext(countsdown:)
- `Transition.blurReplace` (watchOS 10) for swapping status lines — https://developer.apple.com/documentation/swiftui/transition/blurreplace
- `ContentTransition.opacity` / `.interpolate` (watchOS 9) — https://developer.apple.com/documentation/swiftui/contenttransition

Haptics and Crown
- `WKInterfaceDevice.play(_:)` with `WKHapticType.start/.stop/.success/.failure/.retry/.click/.notification` — https://developer.apple.com/documentation/watchkit/wkhaptictype ; meanings per HIG: Start "when starting a timer or any other activity that a person can explicitly start and stop", Stop follows it — https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- `sensoryFeedback(_:trigger:)` (watchOS 10) — https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)
- `digitalCrownRotation(_:)` (watchOS 6) — https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation(_:) ; HIG: "Anchor your app's navigation to the Digital Crown", always back it with touch — https://developer.apple.com/design/human-interface-guidelines/digital-crown

Smart Stack / system entry points
- `RelevanceKit` (watchOS 26): `RelevantContext` (date, sleep, fitness, location), `WidgetRelevance`, `RelevanceConfiguration`, `.associatedKind` — https://developer.apple.com/documentation/relevancekit
- Controls (Control Center, Smart Stack, Ultra Action Button) via `AppIntentControlConfiguration`; Action Button is user-assigned through App Intents — https://developer.apple.com/videos/play/wwdc2025/334/

Type sizes (49mm default = xLarge): Large Title 40, Title 1 38, Title 2 30, Title 3 20, Headline/Body 17, Caption 1 16, Footnote 1 14; watchOS minimum 12 pt, default 16 pt; SF Compact (Rounded in complications) — https://developer.apple.com/design/human-interface-guidelines/typography

## C. Ten ranked principles for "record-first, status-as-magic"

1. **Two taps, zero decisions.** Record then Stop; no title, no pause, no confirmation. Proof: Voice Memos watchOS (Apple Support), Drafts "saved as soon as you tap Done" (Birchtree).
2. **One centred red control plus elapsed time is the whole recording screen.** Proof: Apple's Voice Memos screenshot description (centre Stop, time below, "Recording" label top-right).
3. **Own the audio pipeline; system dictation drops text.** Proof: Drafts forum timeout thread; Just Press Record "unlimited recording time", background recording.
4. **Enter from the wrist, not the app grid.** Complication, Smart Stack (RelevanceKit), Action Button/Controls. Proof: Whisper Memos "raise your wrist, tap the complication"; JPR complication; WWDC25 334.
5. **Status page = distinct look + live values, one hero element.** Proof: HIG Workouts; Harvee's single avatar and The Outsiders' single score (ADA 2026).
6. **Show only state changes worth a glance: progress, required action, result.** Proof: WWDC24 Live Activities for Apple Watch.
7. **Background colour carries meaning; the palette can follow time/state.** Proof: HIG Designing for watchOS ("use background content such as color to convey useful supporting information"); Tide Guide sky-matched palette (ADA 2026).
8. **Animate text, not chrome.** `numericText` for the timer, `blurReplace` for the status line; watchOS 26 glass adds no animation of its own (MacStories) and translucent text over bright backgrounds hurts legibility, so keep status text opaque on dark/gradient ground.
9. **Haptics with documented meaning: Start on record, Stop on end, Success on delivery, Retry on recoverable failure; never overuse.** Proof: HIG Playing haptics (watchOS table).
10. **Crown moves between pages/items; touch mirrors it; Always On dims but keeps layout.** Proof: HIG Digital Crown, HIG Always On; vertical paging is the system idiom (watchOS 10+), so horizontal page swipes should be a deliberate, Workout-style exception (controls / metrics / media layout, WWDC21 10009) **[the three-page horizontal layout for this app is a product decision, not an Apple recommendation]**.

## Gaps
- No primary source for a waveform or Crown use in watchOS Voice Memos.
- SmartGym, Structured, Dot, Streaks, Wristcast watch-screen specifics not verified.
- watchOS 26 toolbar/glass behaviour was checked via docs and the MacStories review, not on device.
