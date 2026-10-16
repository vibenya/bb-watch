# Development handoff — 2026-10-16

## Latest evidence

The updated app was installed and launched on a physical Apple Watch Ultra 2
running watchOS 27.0.1 using Xcode 27.1. The user subsequently dictated and sent
a message from the watch and reported that it worked well. This verifies a real
record/send smoke path; it does not prove standalone LTE, long-term connection
recovery, power-loss bounds or every acceptance criterion.

Latest fixes: single-flight auth; one GET-only 401 retry; bounded timeouts;
all active sidebar-bootstrap chats; selective bounded pending-question fetches;
progressive refresh; audio assembly off the main actor; bounded diagnostics;
Chats pins/activity/folding/search; explicit child-chat recipients.
Full checks passed before the final navigation-owner cleanup; that final cleanup
passed strict Swift 6 typechecking and the signed device build. Independent review
identified child-recipient selection and the fix was verified before installation.

## Next work

1. Reproduce any renewed connection/hang reports and inspect the private watch
   diagnostics file (`Application Support/BBWatch/diagnostics.log`). No BB crash
   report was found in the retrieved catalogue; the original hang cause is not proven.
2. Validate standalone LTE/Wi-Fi, interruption/recovery, long recording and battery
   behavior on hardware. Preserve recordings and unknown delivery states.
3. Extend shared Chats configuration: folders/colors and unread state, using the
   source-backed contracts in `specs/chats-watch-integration.md`.
4. Design a bounded native plugin representation; the iOS WebView integration
   is not a watchOS native plugin framework.
5. Complete summaries, push/complications, broader question types and accessibility.

`native/IMPLEMENTATION-STATUS.md` is the original criterion-level baseline;
its older unverified entries must be read alongside this newer handoff and
`native/VALIDATION.md`. Do not mark all criteria done from one successful message.

## Build and distribution

Source publication is MIT; official artwork and screenshots containing it are
excluded. Add owned artwork at README paths before a full Xcode build. The
maintainer's local checkout retains those ignored files for device development.
No binary release, App Store submission or production backend change accompanies
this source publication. No actual credentials or device signing identities belong here.
