# Privacy Policy

<h3 align="center">
  <a href="README.en.md">README</a> |
  <a href="PRIVACY.en.md">English</a> |
  <a href="PRIVACY.zh-CN.md">中文</a>
</h3>

Last updated: May 14, 2026

Pulse is a local macOS menu bar utility. It is designed to show system status on the Mac where it is running.

## Data Pulse Reads

Pulse may read local system metrics including:

- CPU usage
- Memory usage
- Disk capacity and disk I/O counters
- Network byte counters
- Battery status
- Thermal state
- The system's last boot time, used to calculate system runtime
- Names of running processes and their CPU and memory usage
- Local app bundle paths used to display app icons

These values are used only to render the app interface. They are not uploaded or used for persistent tracking.

## Data Pulse Does Not Collect

Pulse does not collect, store, or transmit:

- Personal files
- Contacts, photos, calendars, location, or clipboard data
- Passwords, credentials, or Keychain contents
- In-app behavior analytics or feature-usage telemetry
- Device serial numbers or persistent tracking identifiers

## Network Usage

Pulse requests the TimeLikeSilver-hosted appcast over HTTPS to check whether a new version is available. When the user clicks Update, Pulse downloads the matching release archive and Sparkle verifies its signature before installation.

As with ordinary HTTPS requests, the appcast request may be processed with standard request metadata such as IP address, user agent, request time, and requested path. TimeLikeSilver may use these requests for security, operations, and aggregate update-check counts to understand Pulse runtime trends. Update checks do not attach CPU, memory, device model, system boot time, process list, app bundle paths, file contents, or Sparkle system profiling data.

## Local Preferences

Pulse may store local preferences, such as language, appearance, and launch-at-login settings, using macOS local storage.
