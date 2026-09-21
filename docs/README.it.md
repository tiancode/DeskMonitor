# DeskMonitor

[简体中文](../README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (BR)](README.pt-BR.md) · [Русский](README.ru.md) · **Italiano**

Un widget flottante per la scrivania di macOS che mostra in tempo reale
**CPU / GPU / memoria / lettura e scrittura del disco / traffico di rete**.
SwiftUI nativo, un solo processo, nessuna dipendenza, tutto letto tramite API di sistema di basso
livello: **niente sudo**.

## Compilare ed eseguire

```bash
./build.sh              # compilazione + bundle + firma ad hoc
open DeskMonitor.app
```

`DeskMonitor --probe` stampa 5 giri di campionamento in testo semplice, comodo per un confronto con
Monitoraggio Attività o `top`.

## Lingue

L’interfaccia segue la lingua di sistema, 11 in tutto:

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Deutsch · Français · Español ·
Português (BR) · Русский · Italiano

Le altre lingue ricadono sull’inglese. Si può anche assegnare una lingua solo a questa app in
«Impostazioni di Sistema › Generali › Lingua e Zona › Applicazioni».

Per aggiungere una lingua basta copiare `Resources/en.lproj/`, rinominarla con il codice della
lingua, tradurla e aggiungere quel codice a `CFBundleLocalizations` in `Info.plist`. Il codice non
si tocca.

## Comandi

L’app non occupa il Dock e **per impostazione predefinita neanche la barra dei menu**: tutte le
impostazioni stanno nel menu che si apre **facendo clic destro sul pannello**.

| Azione | Come |
|---|---|
| Spostare | Trascina il pannello da un punto qualsiasi (la posizione viene ricordata e l’ancoraggio si disattiva) |
| Posizione di ancoraggio | Clic destro → Posizione di ancoraggio: In alto a sinistra / In alto a destra / In basso a sinistra / In basso a destra / Posizione libera |
| Livello finestra | Clic destro → Livello finestra: Sulla scrivania / Finestra normale / Sempre in primo piano |
| Intervallo | Clic destro → Intervallo di aggiornamento: 0,5 / 1 / 2 / 5 s |
| Opacità | Clic destro → Opacità: 50% / 70% / 85% / 100% |
| Icona nella barra dei menu | Clic destro → Mostra icona nella barra dei menu (disattivata di default) |
| Avvio al login | Clic destro → Apri al login |
| Uscita | Clic destro → Esci |

Scelto un angolo, il pannello ci torna anche dopo un cambio di schermo o di risoluzione.
Con l’icona nella barra dei menu disattivata il menu non propone «Nascondi pannello»: una volta
nascosto non resterebbe alcun modo per richiamarlo.

Il livello predefinito è «Sulla scrivania»: sopra lo sfondo e le icone della scrivania, sotto le
finestre delle altre app. È il comportamento che ci si aspetta da un widget da scrivania. Per
tenerlo sempre visibile passa a «Sempre in primo piano».

## Origine dei dati

| Metrica | API | Note |
|---|---|---|
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Conteggi di tick per core, differenza fra due campioni: la stessa fonte di Monitoraggio Attività |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | Su Apple Silicon senza root; è `powermetrics` a richiedere sudo |
| Memoria | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | Usata = app + riservata (wired) + compressa, come in Monitoraggio Attività |
| Pressione memoria | `kern.memorystatus_vm_pressure_level` | Una memoria «usata» alta non significa affanno: il segnale vero è la pressione |
| Disco | IORegistry `IOBlockStorageDriver` → `Statistics` | Differenza dei byte cumulati ÷ intervallo = velocità istantanea |
| Capacità | `statfs` | Spazio libero / totale del disco di avvio, gli stessi numeri di `df` |
| Rete | `sysctl(NET_RT_IFLIST2)` → `if_data64` | Byte dell’interfaccia principale, indicata da PrimaryInterface di `SCDynamicStore` |

Due fonti facili da leggere male:

**`In use system memory` di `IOAccelerator` non è VRAM.** Con la memoria unificata segue la memoria
di sistema e su una macchina da 512 GB arriva a dichiarare oltre 300 GB. Per questo la riga GPU
mostra solo l’utilizzo e il picco recente.

**I contatori di byte dell’interfaccia portano solo i 32 bit bassi.** I valori `ifi_ibytes` /
`ifi_obytes` che l’app legge da `NET_RT_IFLIST2` sono troncati: i 64 bit completi arrivano solo ai
processi firmati da Apple. Gli incrementi vengono quindi calcolati modulo 2³², il che resta corretto
finché un intervallo di campionamento trasporta meno di 4 GB. I valori assoluti sono inutilizzabili,
perciò i totali di sessione vengono accumulati dagli incrementi.

## Struttura

```
Sources/DeskMonitor/
├── main.swift              punto d’ingresso, barra dei menu, azioni del menu
├── WidgetWindow.swift      finestra senza bordo trascinabile + livelli / ancoraggio agli angoli
├── Probe.swift             modalità di verifica testuale --probe
├── Localization.swift      ricerca dei testi
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift cadenza dei campionamenti: lettura in background, pubblicazione sul thread principale
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift impaginazione del pannello
    ├── Sparkline.swift     sparkline / sparkline speculare
    └── VisualEffectView.swift  sfondo smerigliato

Resources/
├── en.lproj/               inglese (lingua base, la chiave È il testo inglese)
└── …                       zh-Hans / zh-Hant / ja / ko / de / fr / es / pt-BR / ru / it
```
