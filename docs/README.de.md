# DeskMonitor

[简体中文](../README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Deutsch** · [Français](README.fr.md) · [Español](README.es.md) · [Português (BR)](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

Ein schwebendes Schreibtisch-Widget für macOS, das **CPU / GPU / Speicher / Laufwerkszugriffe /
Netzwerkdurchsatz** in Echtzeit anzeigt.
Natives SwiftUI, ein Prozess, keine Abhängigkeiten, alle Werte über systemnahe APIs — **ohne sudo**.

## Bauen und starten

```bash
./build.sh              # übersetzen + bündeln + Ad-hoc-Signatur
open DeskMonitor.app
```

`DeskMonitor --probe` gibt fünf Messrunden als reinen Text aus — praktisch zum Abgleich mit der
Aktivitätsanzeige oder `top`.

## Sprachen

Die Oberfläche folgt der Systemsprache, insgesamt 11:

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Deutsch · Français · Español ·
Português (BR) · Русский · Italiano

Alle anderen Sprachen fallen auf Englisch zurück. Unter
„Systemeinstellungen › Allgemein › Sprache & Region › Apps" lässt sich auch nur für diese App
eine eigene Sprache wählen.

Für eine weitere Sprache genügt es, `Resources/en.lproj/` zu kopieren, auf den Sprachcode
umzubenennen, zu übersetzen und diesen Code in `Info.plist` unter `CFBundleLocalizations`
einzutragen. Am Code ändert sich nichts.

## Bedienung

Die App belegt keinen Platz im Dock und **standardmäßig auch keinen in der Menüleiste** — alle
Einstellungen stecken im Menü, das ein **Rechtsklick auf das Panel** öffnet.

| Aktion | Weg |
|---|---|
| Verschieben | Panel an beliebiger Stelle ziehen (Position wird gemerkt, Ziehen hebt das Einrasten auf) |
| Einrastposition | Rechtsklick → Einrastposition: Oben links / Oben rechts / Unten links / Unten rechts / Frei platzieren |
| Fensterebene | Rechtsklick → Fensterebene: Auf dem Schreibtisch / Normales Fenster / Immer im Vordergrund |
| Aktualisierungsintervall | Rechtsklick → Aktualisierungsintervall: 0,5 / 1 / 2 / 5 s |
| Deckkraft | Rechtsklick → Deckkraft: 50 % / 70 % / 85 % / 100 % |
| Menüleistensymbol | Rechtsklick → Menüleistensymbol anzeigen (standardmäßig aus) |
| Beim Anmelden starten | Rechtsklick → Bei der Anmeldung starten |
| Beenden | Rechtsklick → Beenden |

Ist eine Ecke gewählt, rastet das Panel auch nach einem Display- oder Auflösungswechsel wieder dort ein.
Ohne Menüleistensymbol bietet das Menü kein „Panel ausblenden" an — ausgeblendet gäbe es keinen Weg zurück.

Die Standardebene ist „Auf dem Schreibtisch": über dem Hintergrundbild und den Schreibtischsymbolen,
hinter den Fenstern anderer Apps. Genau so soll sich ein Schreibtisch-Widget anfühlen.
Wer es immer sehen will, schaltet auf „Immer im Vordergrund".

## Datenquellen

| Messwert | API | Anmerkung |
|---|---|---|
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Tick-Zähler je Kern, Differenz zweier Messungen — dieselbe Quelle wie die Aktivitätsanzeige |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | Auf Apple Silicon ohne root; sudo braucht nur `powermetrics` |
| Speicher | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | Benutzt = App + reserviert (wired) + komprimiert, wie in der Aktivitätsanzeige |
| Speicherdruck | `kern.memorystatus_vm_pressure_level` | Ein hoher „Benutzt"-Wert heißt nicht Knappheit — der Druck ist das eigentliche Signal |
| Laufwerk | IORegistry `IOBlockStorageDriver` → `Statistics` | Differenz der kumulierten Bytes ÷ Intervall = aktueller Durchsatz |
| Kapazität | `statfs` | Frei / gesamt des Startvolumes, dieselben Zahlen wie `df` |
| Netzwerk | `sysctl(NET_RT_IFLIST2)` → `if_data64` | Bytes der primären Schnittstelle; welche das ist, sagt PrimaryInterface aus `SCDynamicStore` |

Zwei Quellen, die leicht falsch gelesen werden:

**`In use system memory` aus `IOAccelerator` ist kein VRAM.** Bei Unified Memory folgt der Wert dem
Systemspeicher und meldet auf einer 512-GB-Maschine über 300 GB. Deshalb zeigt die GPU-Zeile nur
Auslastung und jüngsten Spitzenwert.

**Die Byte-Zähler der Schnittstelle führen nur die unteren 32 Bit.** Die `ifi_ibytes` / `ifi_obytes`,
die diese App aus `NET_RT_IFLIST2` liest, sind abgeschnitten — die vollen 64 Bit bekommen nur von
Apple signierte Prozesse. Die Differenzen werden daher modulo 2³² gerechnet und bleiben korrekt,
solange ein Messintervall unter 4 GB transportiert. Die Absolutwerte sind unbrauchbar, die
Sitzungssummen werden deshalb selbst aus den Differenzen aufaddiert.

## Aufbau

```
Sources/DeskMonitor/
├── main.swift              Einstiegspunkt, Menüleiste, Menüaktionen
├── WidgetWindow.swift      randloses, ziehbares Fenster + Ebenen / Eckeneinrasten
├── Probe.swift             Textmodus --probe zur Überprüfung
├── Localization.swift      Textsuche
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift Messtakt: Lesen im Hintergrund, Veröffentlichen im Main-Thread
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift Panel-Layout
    ├── Sparkline.swift     Sparkline / gespiegelte Sparkline
    └── VisualEffectView.swift  Milchglas-Hintergrund

Resources/
├── en.lproj/               Englisch (Basissprache, der Schlüssel IST der englische Text)
└── …                       zh-Hans / zh-Hant / ja / ko / de / fr / es / pt-BR / ru / it
```
