# Internal Changelog

This file is for maintainers. Keep the public changelog in `README.md` and
`docs/README.en.md` focused on user-facing release notes. Use this file for
implementation context, product decisions, privacy boundaries, thresholds, and
verification notes that would make the public changelog too noisy.

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
- High process CPU values use warning colors: orange at 100% and a stronger
  orange-red at 200%.

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
  - on battery: green at 40% or higher, yellow below 40%, orange below 20%, red
    below 10%;
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
