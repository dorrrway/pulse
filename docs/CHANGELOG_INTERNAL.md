# Internal Changelog

This file is for maintainers. Keep the public changelog in `README.md` and
`docs/README.en.md` focused on user-facing release notes. Use this file for
implementation context, product decisions, privacy boundaries, thresholds, and
verification notes that would make the public changelog too noisy.

## Unreleased

### Screenshots

- Added Screenshots as an island module using the native macOS `screencapture`
  tool. Full-screen capture uses `-c -i -w -S -x` so the user can choose and
  confirm the target display before copying; window capture uses
  `-c -i -w -o -x` so macOS omits the selected window's system shadow;
  custom selection uses `-c -i -s -x`.
- Screenshot actions temporarily order out the Pulse island panel before
  capture, then restore the seed panel after `screencapture` exits so Pulse does
  not appear in its own screenshots.
- The Screenshots panel now exposes the hide-before-capture behavior as a local
  preference. It defaults to enabled and is shared by panel actions and global
  screenshot shortcuts so users can intentionally include Pulse itself in a
  screenshot when needed.
- The hide-before-capture switch uses a local SwiftUI `ToggleStyle` so its
  enabled state stays green inside the nonactivating island panel instead of
  depending on the system `NSSwitch` tint behavior.
- The hide-before-capture label and switch are grouped together at the trailing
  edge of the Screenshots panel footer instead of splitting label and control.
- Screenshot actions now preflight and request macOS Screen Recording access
  before hiding the island. If `screencapture` still reports a TCC denial, Pulse
  restores the island and opens the Screen Recording privacy pane instead of
  failing silently.
- Screenshot preview presentation now records `NSPasteboard.general.changeCount`
  before invoking `screencapture` and only reads a preview image if the capture
  result reports success and the pasteboard changed. This prevents native picker
  cancellation from showing the previous clipboard screenshot when the system
  exits without writing a new image.
- The Screenshots island panel now checks `CGPreflightScreenCaptureAccess()` on
  appearance and when Pulse becomes active. If access is missing, it shows an
  orange inline notice with an explicit Authorize action; the capture buttons
  remain usable and still run the existing request path.
- Screenshot preview editing uses a separate floating `NSPanel` modeled after
  the pinned screenshot panel. SwiftUI owns the edit marks and an adaptive
  icon-only bottom toolbar with a separated leftmost hand Move button followed
  by rectangle, circle, arrow, pen, mosaic, text, undo, save, share, pin,
  cancel, and done; AppKit only owns window lifetime and native save/share
  panels.
- Pinned screenshot panels now keep the same borderless image-only surface while
  using AppKit's native resizable window behavior. The panel keeps the original
  image aspect ratio through `contentAspectRatio` and relies on existing
  `contentMinSize` / `contentMaxSize` limits instead of recalculating frames
  from SwiftUI mouse-drag events.
- The screenshot editor starts with no selected tool. While no tool is selected,
  dragging the image moves the editor window; after a tool is selected, the
  image region stops participating in window dragging so drawing arrows, shapes,
  or mosaics does not move the panel.
- Mosaic edit marks now use a brush stroke model with normalized point samples
  and a display-relative brush diameter. The SwiftUI preview and AppKit renderer
  both draw from a source-image pixelated copy clipped to the same round-capped
  stroke, so redaction follows the screenshot's colors instead of overlaying
  synthetic gray tiles.
- Pen and text edit marks are rendered through the same local renderer as shape
  and mosaic marks, so editor save/share/pin actions always operate on the
  currently edited image rather than the original screenshot.
- Added a Bluetooth island module backed by `IOBluetoothDevice` for paired
  device state/actions, IORegistry battery fields for connected Apple HID
  devices, and macOS Bluetooth profile battery fields for AirPods left/right/case
  values when the system reports them. The feature adds
  `NSBluetoothAlwaysUsageDescription` and updates public privacy docs.
- Bluetooth now checks CoreBluetooth authorization before sampling devices. The
  island shows an inline authorization prompt while access is undetermined, then
  collapses before creating the `CBCentralManager` that triggers the macOS
  Bluetooth permission dialog.
- Bluetooth device rows now handle connection actions directly: disconnected
  rows connect on click, connected rows ask for confirmation before disconnecting,
  and disconnected rows use dimmer text/icons plus translucent battery rings for
  stale-but-readable battery values.
- Bluetooth device row hit testing now covers the full non-battery row area, so
  the blank space between the device title and battery cluster connects or asks
  for disconnect confirmation while the battery rings remain display-only.
- Bluetooth battery levels now feed the island alert queue after authorization.
  Devices at or below 20% or 10% reuse the existing two-line alert style,
  battery threshold icons, warning colors, animation, and one-alert-per-continuous
  state behavior, with Bluetooth-specific device/part copy.
- Bluetooth device and battery icons now prefer device-specific SF Symbols for
  AirPods, AirPods Pro, AirPods Max, Beats earbuds/headphones, keyboards,
  trackpads, mice, phones, tablets, and Macs. The renderer resolves the first
  available symbol candidate at runtime and falls back to a neutral Bluetooth
  glyph to avoid blank icons on older symbol sets.
- Bluetooth audio device SF Symbol matching now uses an explicit profile table
  for AirPods, AirPods Pro, AirPods 3/4, and Beats variants. AirPods Pro and
  newer AirPods charging cases use the canonical `.chargingcase.wireless`
  symbols instead of falling back to generic AirPods cases.
- Debug settings now include a Bluetooth low-battery alert preview using a fake
  AirPods Pro left-battery critical alert. It goes through the same island alert
  preview path as the existing resource monitor alert previews.
- Bluetooth low-battery items now also enter the normal compact island seed
  rotation alongside Memory, CPU, and internal Battery while the low-battery
  state remains active, instead of only appearing as one-time critical alerts.
- Bluetooth battery rings now surface charging state for connected Apple HID
  devices when macOS exposes extended battery status. Charging rings stay green,
  lightly alternate the center battery icon with a bolt symbol, and are excluded
  from low-battery Bluetooth alerts.
- The Bluetooth panel footer now keeps a Bluetooth Settings shortcut on the
  lower left and moves the paired-device count next to the lower-right refresh
  control.
- Bluetooth and Applications footer refresh actions now render without button
  backgrounds, and the Bluetooth Settings shortcut uses the same Bluetooth glyph
  as the Bluetooth module title instead of the settings gear.
- Added local shortcut preferences and global hot key IDs for full-screen,
  window, and selection capture. Duplicate shortcut assignment still moves the
  shortcut to the most recently edited action.
- Screenshot shortcut recorders are also available directly in the Screenshots
  island panel so users can assign or clear each capture shortcut next to the
  action it triggers.
- Shortcut recording no longer requires Command, Option, Control, or Shift.
  Single-key shortcuts, including extended function keys such as F13-F19, are
  accepted when macOS delivers them as key events.
- After a successful Pulse screenshot, the island reads the image from the
  system clipboard and shows a dedicated screenshot preview reminder with a
  taller compact surface; it auto-collapses after 3 seconds only when the
  reminder is not hovered.
- The screenshot preview reminder header now derives its row height from the
  same measured island header row as the expanded Resource Monitor surface,
  rather than combining a fixed 34 pt row with extra top padding.
- The screenshot preview reminder now includes explicit Save, Share, and
  Recognize Text buttons below the image. Save uses `NSSavePanel` and writes a
  PNG only to the user-selected URL, Share uses the native
  `NSSharingServicePicker`, and Recognize Text runs local Vision OCR on demand
  before showing a selectable result dialog with an explicit Copy Text action.
- The screenshot preview reminder now includes a Pin action that opens the
  current image in a separate borderless floating `NSPanel`. Pinned screenshot
  windows show only the image, can be dragged, reveal a pin close control on
  hover, and support multiple simultaneous pinned images.
- Dragging the screenshot preview image now creates an `NSItemProvider` with PNG
  data plus a temporary PNG file representation, so Finder, chat windows, and
  document editors can accept the preview without adding another visible
  control. Temporary drag exports are kept under the system temporary directory
  and stale exports are cleaned up by later drags.
- Screenshot mode buttons now use the provided vector PDF assets for full
  screen, window, and custom selection instead of SF Symbols.
- Public README, English README, and both privacy policies now document that
  screenshots are user-triggered, written to the system clipboard, and may enter
  local Clipboard history when clipboard monitoring is enabled.

## 2.2.0 - 2026-05-27

### Compatibility

- Lowered `MACOSX_DEPLOYMENT_TARGET` from 26.0 to 15.0 across the app and test
  targets. `LSMinimumSystemVersion` continues to derive from that build setting.
- Kept the macOS 26 and newer favorite-removal drag feedback path on
  `DropOperation.delete`, while macOS 15 through 25 use `DropOperation.move`
  and still perform removal through the existing drop delegate.
- Guarded `NSPasteboard.accessBehavior`, which is only available on macOS 15.4
  and newer. macOS 15.0 through 15.3 report the pasteboard behavior as the
  system default while using the same read/write path.
- Type-erased the private Pulse Island hosting view to avoid a Swift 6.3.2
  Release optimizer crash when archiving the app with a macOS 15.0 deployment
  target. Hit testing and controller ownership remain unchanged.

## 2.1.0 - 2026-05-27

### Clipboard

- Added Clipboard as the third independent Pulse Island module alongside
  Resource Monitor and Applications. The module is selected only through the
  existing island module switcher and does not feed data into resource sampling,
  installed-app cataloging, pinned panels, or update checks.
- Clipboard monitoring starts by default with a 0.5 second `NSPasteboard`
  `changeCount` poll. macOS pasteboard access behavior and read failures are
  surfaced in the Clipboard panel without clearing existing history.
- Clipboard history is persisted locally as JSON metadata plus blob files under
  Application Support. The default retention policy does not prune by entry
  count and keeps history for 30 days; Settings can switch the entry limit to
  100, 500, 1000, or unlimited, switch the retention time to unlimited, 7 days,
  30 days, or 90 days, and the clear action removes metadata, raw pasteboard
  blobs, OCR text, and memory state.
- Pasteboard items preserve original type/data representations for copying back
  to the system clipboard. Parsed text, URLs, files, and images are used for UI
  and search, with fallback writes only when original representations are no
  longer available.
- Sensitive and temporary marker types, including `ConcealedType`,
  `TransientType`, `AutoGeneratedType`, remote clipboard, and source markers, are
  first-class metadata and are not skipped. Marker-backed entries stay searchable
  and copyable while the UI masks sensitive content by default.
- OCR is implemented with the local Vision framework and is off by default. When
  enabled, recognized text is stored only in the local search index.
- The Clipboard panel now has a top-level content filter for all, text, images,
  links, and files. Mixed entries appear in each matching category based on
  their contained pasteboard items.
- Clipboard history now ignores pasteboard changes written by its own Copy
  action. External duplicate payloads are de-duplicated by fingerprint and move
  the existing entry to the top instead of creating repeated rows.
- Clipboard recording now publishes a lightweight record notice after a payload
  is stored or an external duplicate is refreshed. The resting island consumes
  that notice to show a 1.5 second content-type icon, non-notched copied label,
  and completion checkmark, reusing the existing seed rolling transition and
  without expanding the island.
- The non-notched Clipboard record reminder now rolls the leading icon and
  copied label as one group without resizing the seed layout, matching the
  completion checkmark transition.
- Double-clicking a Clipboard row writes that entry back to the system
  pasteboard and posts one Command-V key event to the currently focused target.
  This path requires macOS Accessibility permission and does not read target app
  input, windows, or accessibility contents.
- Public README, English README, privacy policies, and the Clipboard design note
  now document the clipboard read/storage boundary, sensitive marker behavior,
  local persistence, and local-only OCR.
- The Clipboard panel hides search while there is no history, removes the footer
  OCR status text, moves the count to the right side, and exposes a left-aligned
  Clear all action with visible text. The empty state now uses the Clipboard
  module icon and user-facing copy.
- Remote clipboard payloads that arrive as image file URLs, such as Universal
  Clipboard temporary `.png` files, are classified as images when they also
  carry image data and their file extension conforms to an image type instead of
  falling through to Files.
- File URLs carried in generic URL pasteboard representations are normalized
  into Files, and remote clipboard entries no longer use the local foreground
  app as an inferred source when macOS does not declare the real remote source.
- When macOS omits `org.nspasteboard.source`, Clipboard now recognizes explicit
  WeChat pasteboard type markers, such as
  `com.trolltech.anymime.WeChatScreenshotFormat`, as a declared application
  source so remote WeChat images can use the local WeChat icon when available,
  including existing stored entries that still retain those raw pasteboard
  representations.
- Clipboard text decoding now treats `public.utf16-plain-text` payloads without
  a byte-order mark as little-endian text. Stored text entries with blob-backed
  representations are reparsed on load so matching local history repairs
  automatically.

### Dynamic Island-style Surface

- Expanded-state header content now has its own reveal phase. On open, the
  header text, module icon, and common action buttons wait briefly before
  fading in, while the attached panel keeps its existing later reveal delay. On
  close, the header fades out quickly before the surface unmount delay
  completes.
- Settings and Quit are now owned by the expanded-state common header instead
  of the Resource Monitor panel footer. The resource panel footer keeps
  panel-specific controls only, and pinned Resource Monitor panels place the
  minimize action at the bottom-right corner for balance.
- Removed the Resource Monitor panel's internal `PulseHeaderView`, including
  the repeated app title, device name, and now-unused `PixelGlyph`. The panel
  height now excludes the old header row, and refresh time is only shown in the
  island-attached resource footer, not in pinned Resource Monitor panels.
- The Dynamic Island-style surface and pinned Resource Monitor panel now use
  the display containing the pointer as the current display. The island tracks
  the current display while resting, and the pinned panel keeps a single window
  while migrating to the new display at the same relative position.
- The Applications module now has a separate single-row Favorite Apps strip
  above the app browser. Favorite app bundle paths are stored in UserDefaults,
  list rows use a trailing pin action, and icon tiles can be dragged into the
  strip through SwiftUI drop handling. Favorite apps can also be reordered
  through the same strip-level projected layout used for library drops. Favorite
  apps can be dragged from the strip back into the app browser area to remove
  them, with a lightweight local shatter effect on the source tile before
  removal. The app browser opens in icon view by default, with the footer switch
  ordered icon view first and list view second.
- Favorite-app drag and drop now advertises a Pulse-specific own-process item
  representation plus a text representation for SwiftUI/AppKit drop
  compatibility; accepted drops are still gated by the active in-process
  payload. No-op drops immediately before or after the dragged favorite app
  suppress the projected layout, so the visual landing slot only appears where
  releasing would change the order. Dragging a favorite back to the app browser
  now uses the system delete drop operation, and library apps can be dropped
  anywhere inside the favorite strip.
- The island hover-collapse path now defers while any mouse button is pressed,
  so dragging apps inside the Applications panel does not collapse and unmount
  the drop targets before the drag session ends.
- Favorite-app drag placement now uses one continuous strip-level drop delegate
  that maps `DropInfo.location.x` to a projected insertion index. The strip
  renders the projected layout before the store order is committed, so library
  drops and favorite reordering move icons toward their final positions without
  customizing the system drag preview.
- The Applications module now tracks `NSWorkspace` running-app launch and
  termination notifications, rendering running apps with a non-gray highlighted
  dot below the app icon. The state is kept in memory only and is not persisted.
- Application launch requests now flow through an injectable open action. The
  island passes its existing collapse action into the Applications panel, so
  favorite tiles, list rows, and icon-grid tiles all return the surface to the
  resting state after requesting `NSWorkspace` to open the selected app.
- Expanded-state module switching now uses horizontal drag and horizontal scroll
  input across the full module row, plus click-to-switch on each module item.
  The header renders all modules in a horizontal selector and offsets the row so
  the selected module remains centered, while the attached panel transitions
  from the matching horizontal edge.
- The expanded header selector now measures module button content widths and
  uses 24 point inter-item spacing, keeping visual layout and local-event
  hit-testing aligned for click, drag, and horizontal scroll switching.
- Header horizontal scroll switching now maps negative `scrollingDeltaX` to the
  next module, matching the existing drag direction and natural paging behavior
  after AppKit applies the user's scroll-direction preference to scroll deltas.
- New island controllers now default to the Applications module, so a fresh
  install or process restart opens the expanded island on the app-launching
  surface unless a shortcut explicitly selects another module.
- Settings now includes a Shortcuts section with two local preferences for
  waking Clipboard and Applications. The runtime registers those shortcuts with
  Carbon `RegisterEventHotKey`, keeps duplicate assignments exclusive between
  the two actions, and routes each wake action through the island controller so
  the surface opens directly on the matching module.
- Shortcut wake no longer routes through the full seed presentation path when
  the island panel is already mounted. The controller keeps the existing root
  view alive, updates the target module, and expands through the same state
  transition used by pointer hover.

## 2.0.0 - 2026-05-25

### Dynamic Island-style Surface

- Pulse now launches directly into a top-centered nonactivating `NSPanel` for
  the Dynamic Island-style surface and no longer creates a `MenuBarExtra` scene.
- Removed the surface visibility preference, Settings toggle, panel footer
  toggle, and hide action. The top surface is the app's primary control surface;
  Settings and Quit remain available from the surface context menu and expanded
  surface.
- Added the top-centered nonactivating `NSPanel` for the Dynamic Island-style mode.
  It anchors to the current screen, uses `NSScreen` auxiliary top areas when a
  camera housing is present, and falls back to a software island on external or
  non-notched displays.
- The surface hides its top attachment cap above the screen edge so the resting
  state reads as a top status aperture instead of a floating capsule. Hovering
  expands it into a black tray with a secondary control rail, then collapses it
  shortly after the pointer leaves.
- The expanded state uses a compact Resource Monitor header instead of a
  repeated four-metric summary, leaving the attached full panel as the detailed
  monitoring surface and preserving room for later modules.
- The expanded-state header is now a module switcher: horizontal drag or scroll
  switches between Resource Monitor and Applications without changing the
  existing resource monitoring panel.
- Applications is implemented as a separate installed-app catalog and island
  panel. It enumerates standard application directories, reads bundle display
  metadata locally, caches icons in the UI layer, and opens apps through
  `NSWorkspace`.
- The Applications panel footer now keeps the count next to the refresh control
  and adds a local list/icon view switcher; icon view presents app icons and
  names in a Launchpad-like grid without changing the catalog or privacy model.
- On MacBooks with a camera housing, the surface now anchors into one of the
  reported auxiliary top areas instead of using the hidden gap between them as
  the horizontal center point.
- The resting-state seed normally rotates memory and CPU. When internal battery
  power is at or below 20% while unplugged or charging from a low level, battery
  level is appended to the same rotation using the existing warning threshold and
  local battery sample.
- Resting-state seed labels use metric-specific template icons instead of text:
  memory, CPU, 20% battery, 10% battery, and charging battery. Icons inherit the
  same activity tint as the prior label text, including power status colors.
- The top surface labels battery percentage as `电量` / `Battery` while the full
  status card keeps `电源` / `Power` for the broader power-source state.
- Alert-state messages now share a prioritized queue. When unplugged
  internal battery power enters the red threshold at or below 10%, thermal state
  becomes critical, storage is extremely low, or memory pressure is high, the
  surface briefly uses a two-row alert seed, then returns to the resting state
  after 3 seconds. Alerts are shown one at a time in power, thermal, disk, memory
  order, and each continuous condition is shown once.
- Critical alert title rows now use leading template icons in the alert tint:
  low battery reuses the compact battery icon, thermal uses the sun asset,
  disk uses the storage asset, and memory reuses the compact memory icon.
- The memory critical-alert title is shortened to `Memory` / `内存`; the full
  panel still uses `Memory Pressure` / `内存压力` for the system pressure card.
- Critical alert thresholds include their boundary values: battery joins the
  compact rotation at 20%, critical battery alerts start at 10%, disk alerts
  start at 5 GB free or 95% used.
- The alert seed body is wider than the notch-aware resting seed so critical
  alerts visibly expand on MacBooks with a camera housing while staying smaller
  than the fully expanded surface.
- Debug builds expose an Alert Preview row in Settings to trigger the
  same power, thermal, disk, memory, or full critical-alert queue with synthetic
  values. The preview path is compiled out of Release builds and does not alter
  live sampled metrics.

## 1.2.0 - 2026-05-15

### Localization

- System language resolution now checks `Locale.preferredLanguages` before
  falling back to `Locale.autoupdatingCurrent`. This keeps `zh-Hans-US` primary
  language setups in Chinese even when the app process locale or bundle
  development region reports English.

### Appearance

- Applying an appearance preference now updates the hosting `NSWindow` and
  content view together, then invalidates layout and display. The `.system`
  path resolves the current macOS appearance immediately instead of relying on
  SwiftUI to clear a previous optional override, and observes system appearance
  changes while System is selected.

### Distribution

- The release script now builds a styled DMG by generating a bilingual
  installation background, mounting a writable image, applying Finder icon-view
  layout, then converting the result before Developer ID signing, notarization,
  stapling, Sparkle signing, and SHA-256 generation.
- The DMG volume name now includes the current marketing version, so the Finder
  window title matches the released archive.

## 1.1.2 - 2026-05-14

### Updates

- Update checks now use the TimeLikeSilver-hosted appcast endpoint. The request
  can be counted from website logs to estimate aggregate runtime trends without
  adding app-side telemetry or Sparkle system profiling.

### Process Rankings

- High process CPU values use the same staged warning colors for the process
  name and value: yellow at 100% and orange at 200%.

### Status Cards

- Signal cards now use small circular legend dots instead of square markers,
  keeping the colored status indicator visually closer to native status dots.

## 1.1.0 - 2026-05-14

### Floating Panel

- The menu bar panel can be pinned into a draggable floating panel.
- The floating panel supports a minimal mode that shows only CPU, memory,
  network, and disk. The restore control appears on hover so the minimal view
  stays visually compact.
- The full panel uses a fixed height budget instead of internal scrolling. This
  keeps the status layout stable and avoids text being compressed smaller under
  layout pressure.
- The footer spacing was tightened so the bottom controls use less vertical
  space without changing their behavior.
- The pin, collapse, expand, settings, and quit controls continue to use
  fixed-size template icons so their hit targets and visual rhythm stay stable.
- A missing update-state environment in the floating panel was fixed because it
  could crash when pinning the menu panel.

### Process Rankings

- CPU and memory rankings show the top local apps/processes by resource usage.
- Visible rows remain limited to the top three entries to keep the panel
  scannable; the pixel share chart can represent the top five entries.
- Rows can show the local app icon when a bundle path is available.
- Pixel share charts show the ranking composition and can open a detail popover.
- CPU usage is multi-core aware, so values can exceed 100% when a process uses
  more than one core.

### Status Cards

- Memory pressure marker colors are green for normal, yellow for elevated, and
  orange for high.
- Memory pressure thresholds combine memory usage, swap, and compression:
  elevated starts at 80% used, 512 MiB swap, or 10% compressed memory; high
  starts at 90% used, 2 GiB swap, or 20% compressed memory.
- Memory pressure copy is `正常 / 偏高 / 高` in Chinese and `OK / Watch / High`
  in English.
- English memory-pressure detail uses `Comp` instead of `Compressed` to reduce
  visible truncation. Hover help and accessibility keep the full explanation.
- Thermal states use four marker colors: green, yellow, orange, and red.
- Thermal copy is `正常 / 偏热 / 高温 / 严重高温` in Chinese and
  `Normal / Warm / Hot / Very Hot` in English.
- Thermal detail copy distinguishes short-lived states from sustained states,
  such as `温度稳定` before 10 seconds and `持续稳定 48 秒` after that.
- Power marker semantics:
  - no built-in battery: green;
  - plugged in or charging: green;
  - charging marker breathes unless Reduce Motion is enabled;
  - on battery: green at 40% or higher, yellow below 40%, orange at or below
    20%, red at or below 10%;
  - unknown battery percentage stays green because the system did not provide
    enough information for a severity decision.
- Disk I/O card keeps visible `Read` / `Write` labels. The card marker reflects
  activity: blue below 50 MB/s combined read/write, purple at or above 50 MB/s.
- Runtime sampling still runs at the 1-second cadence, but `PulseStore` now
  publishes grouped visible-state changes instead of replacing one full
  snapshot every tick. This keeps the panel feeling realtime while avoiding
  broad SwiftUI invalidation when formatted values did not visibly change.
- Process rankings keep the 6-second window, but path/bundle metadata is
  resolved only for top CPU/memory candidates after lightweight pid, CPU time,
  resident memory, and process-name sampling.
- The four status cards use hover help and accessibility values for full
  descriptions instead of expanding the card or adding more visible text.

### System Runtime

- The full panel includes a System Runtime strip under the status cards.
- Runtime is derived from the system's last boot time.
- Reading the last boot time is documented in the privacy summary because it is
  another local system metric.

### Settings

- Appearance settings support System, Light, and Dark, with System as the
  default.
- Open menu panels, floating panels, and settings windows now sync when the
  appearance setting changes.
- Startup and language settings were simplified by removing redundant section
  titles and helper copy.
- Launch-at-login status is normally hidden and shown only when it needs
  attention.
- The settings window is brought forward when opened from the menu bar so it is
  not hidden behind other windows.
- The Contact row links to the Pulse website from settings.

### Updates

- Sparkle is integrated for update checks and installation.
- When an update is available, the full-panel footer shows an Update button.
- Update checks request the appcast and do not upload system metrics or Sparkle
  system profile data.
- The update button is a text button near the pin control; the previous footer
  monitoring-only status text was removed.

### Privacy And Documentation

- Public privacy wording documents local process names, CPU usage, memory usage,
  app bundle paths, disk I/O, battery, thermal state, network counters, and the
  last boot time.
- Process names, app bundle paths, and resource usage are used only for local UI
  display.
- The appcast request is the only network request described by the update flow.
- Public changelog entries should stay user-facing and consolidated. Detailed
  implementation notes, thresholds, and rationale belong in this file.

### Verification

- Use `git diff --check` for documentation-only changes.
- Use `xcodebuild test -project pulse.xcodeproj -scheme pulse -destination 'platform=macOS'`
  for code changes.
- Use these when menu bar behavior, installation, signing, or local running
  state changes:
  - `scripts/install-local-app.sh`
  - `codesign --verify --deep --strict --verbose=2 /Users/highway/Applications/Pulse.app`
  - `pgrep -afil 'Pulse|pulse'`
