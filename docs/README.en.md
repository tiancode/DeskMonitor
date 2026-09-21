# DeskMonitor

[简体中文](../README.md) · [繁體中文](README.zh-Hant.md) · **English** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (BR)](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

A floating macOS desktop widget showing **CPU / GPU / memory / disk I/O / network throughput** in real time.
Native SwiftUI, single process, no dependencies, everything read through low-level system APIs — **no sudo**.

## Build and run

```bash
./build.sh              # compile + bundle + ad-hoc sign
open DeskMonitor.app
```

`DeskMonitor --probe` prints 5 rounds of samples as plain text, handy for cross-checking
against Activity Monitor / `top`.

## Languages

The interface follows the system language — 11 of them:

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Deutsch · Français · Español ·
Português (BR) · Русский · Italiano

Anything else falls back to English. You can also pick a language for this app alone under
System Settings › General › Language & Region › Applications.

To add one, copy `Resources/en.lproj/`, rename it to the language code and translate it, then add
that code to `CFBundleLocalizations` in `Info.plist`. No code changes needed.

## Controls

The app takes no Dock slot and **no menu bar slot by default** — every setting lives in the menu
you get by **right-clicking the panel**.

| Action | How |
|---|---|
| Move | Drag anywhere on the panel (position is remembered; dragging turns snapping off) |
| Snap Position | Right-click → Snap Position: Top Left / Top Right / Bottom Left / Bottom Right / Free Placement |
| Window Level | Right-click → Window Level: On Desktop / Normal Window / Always on Top |
| Refresh Interval | Right-click → Refresh Interval: 0.5 / 1 / 2 / 5 s |
| Opacity | Right-click → Opacity: 50% / 70% / 85% / 100% |
| Menu bar icon | Right-click → Show Menu Bar Icon (off by default) |
| Launch at login | Right-click → Launch at Login |
| Quit | Right-click → Quit |

Once a corner is chosen, the panel snaps back to it across display and resolution changes.
With the menu bar icon off, the menu offers no "Hide Panel" — hiding it would leave no way back in.

The default level is "On Desktop": above the wallpaper and desktop icons, covered by other apps'
windows. That is what a desktop widget should feel like. Switch to "Always on Top" to keep it visible.

## Data sources

| Metric | API | Notes |
|---|---|---|
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Per-core tick counts, delta between samples — the same source Activity Monitor uses |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | No root needed on Apple Silicon; only `powermetrics` wants sudo |
| Memory | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | Used = app + wired + compressed, matching Activity Monitor |
| Memory pressure | `kern.memorystatus_vm_pressure_level` | A high "used" figure does not mean strain — pressure is the real signal |
| Disk | IORegistry `IOBlockStorageDriver` → `Statistics` | Cumulative byte counters, delta ÷ interval = live throughput |
| Capacity | `statfs` | Startup disk free / total, the same figures as `df` |
| Network | `sysctl(NET_RT_IFLIST2)` → `if_data64` | Byte counters of the primary interface, which comes from `SCDynamicStore`'s PrimaryInterface |

Two sources that are easy to misread:

**`IOAccelerator`'s `In use system memory` is not VRAM.** Under unified memory it tracks system
memory and reports 300+ GB on a 512 GB machine. That is why the GPU row shows only utilization
and recent peak.

**Interface byte counters carry only the low 32 bits.** The `ifi_ibytes` / `ifi_obytes` this app
reads from `NET_RT_IFLIST2` are truncated — only Apple-signed processes get the full 64 bits.
Deltas are therefore computed modulo 2³², which stays correct as long as a single sampling interval
carries less than 4 GB. The absolute values are unusable, so session totals are accumulated
from the deltas instead.

## Layout

```
Sources/DeskMonitor/
├── main.swift              app entry, menu bar, menu actions
├── WidgetWindow.swift      borderless draggable window + level / corner-snap definitions
├── Probe.swift             --probe text verification mode
├── Localization.swift      string lookup
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift sampling scheduler: read on a background queue, publish on main
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift panel layout
    ├── Sparkline.swift     sparkline / mirrored sparkline
    └── VisualEffectView.swift  frosted-glass background

Resources/
├── en.lproj/               English (base language, the key IS the English string)
└── …                       zh-Hans / zh-Hant / ja / ko / de / fr / es / pt-BR / ru / it
```
