# Internal Changelog

This file is for maintainers. Keep the public changelog in `README.md` and
`docs/README.en.md` focused on user-facing release notes. Use this file for
implementation context, product decisions, privacy boundaries, thresholds, and
verification notes that would make the public changelog too noisy.

## Unreleased

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
- The expanded-state header is now a module switcher: vertical drag or scroll switches
  between Resource Monitor and Applications without changing the existing
  resource monitoring panel.
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
