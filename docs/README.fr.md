# DeskMonitor

[简体中文](../README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · **Français** · [Español](README.es.md) · [Português (BR)](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

Un widget flottant pour le bureau macOS qui affiche en temps réel
**processeur / GPU / mémoire / accès disque / débit réseau**.
SwiftUI natif, un seul processus, aucune dépendance, tout passe par des API système bas niveau —
**sans sudo**.

## Compiler et lancer

```bash
./build.sh              # compilation + bundle + signature ad hoc
open DeskMonitor.app
```

`DeskMonitor --probe` affiche 5 séries de mesures en texte brut, pratique pour recouper avec le
Moniteur d’activité ou `top`.

## Langues

L’interface suit la langue du système, 11 au total :

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Deutsch · Français · Español ·
Português (BR) · Русский · Italiano

Les autres langues reviennent à l’anglais. Vous pouvez aussi choisir une langue pour cette seule app
dans « Réglages Système › Général › Langue et région › Applications ».

Pour ajouter une langue, copiez `Resources/en.lproj/`, renommez le dossier avec le code de langue,
traduisez, puis ajoutez ce code à `CFBundleLocalizations` dans `Info.plist`. Aucun changement de code.

## Utilisation

L’app n’occupe pas le Dock ni, **par défaut, la barre des menus** — tous les réglages sont dans le
menu qu’ouvre un **clic droit sur le panneau**.

| Action | Comment |
|---|---|
| Déplacer | Faites glisser le panneau n’importe où (la position est mémorisée et l’ancrage est levé) |
| Position d’ancrage | Clic droit → Position d’ancrage : En haut à gauche / En haut à droite / En bas à gauche / En bas à droite / Placement libre |
| Niveau de fenêtre | Clic droit → Niveau de fenêtre : Sur le bureau / Fenêtre normale / Toujours devant |
| Intervalle | Clic droit → Intervalle d’actualisation : 0,5 / 1 / 2 / 5 s |
| Opacité | Clic droit → Opacité : 50 % / 70 % / 85 % / 100 % |
| Icône de la barre des menus | Clic droit → Afficher l’icône dans la barre des menus (désactivée par défaut) |
| Lancement à l’ouverture | Clic droit → Lancer à l’ouverture de session |
| Quitter | Clic droit → Quitter |

Une fois un coin choisi, le panneau s’y replace après un changement d’écran ou de résolution.
Sans icône dans la barre des menus, le menu ne propose pas « Masquer le panneau » : une fois masqué,
il n’y aurait plus aucun moyen de le rappeler.

Le niveau par défaut est « Sur le bureau » : au-dessus du fond d’écran et des icônes, sous les
fenêtres des autres apps — le comportement attendu d’un widget de bureau. Pour le garder visible en
permanence, passez à « Toujours devant ».

## Sources des données

| Mesure | API | Remarque |
|---|---|---|
| Processeur | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Compteurs de ticks par cœur, différence entre deux mesures — la source du Moniteur d’activité |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | Pas de root sur Apple Silicon ; c’est `powermetrics` qui exige sudo |
| Mémoire | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | Utilisée = app + réservée (wired) + compressée, comme le Moniteur d’activité |
| Pression mémoire | `kern.memorystatus_vm_pressure_level` | Une mémoire « utilisée » élevée n’indique pas une tension ; la pression est le vrai signal |
| Disque | IORegistry `IOBlockStorageDriver` → `Statistics` | Différence des octets cumulés ÷ intervalle = débit instantané |
| Capacité | `statfs` | Espace libre / total du disque de démarrage, les chiffres de `df` |
| Réseau | `sysctl(NET_RT_IFLIST2)` → `if_data64` | Octets de l’interface principale, désignée par PrimaryInterface de `SCDynamicStore` |

Deux sources faciles à mal lire :

**`In use system memory` d’`IOAccelerator` n’est pas de la VRAM.** En mémoire unifiée, cette valeur
suit la mémoire système et annonce plus de 300 Go sur une machine de 512 Go. La ligne GPU n’affiche
donc que le taux d’utilisation et le pic récent.

**Les compteurs d’octets de l’interface ne portent que les 32 bits de poids faible.** Les
`ifi_ibytes` / `ifi_obytes` lus depuis `NET_RT_IFLIST2` sont tronqués : seuls les processus signés
par Apple reçoivent les 64 bits complets. Les écarts sont donc calculés modulo 2³², ce qui reste
juste tant qu’un intervalle de mesure transporte moins de 4 Go. Les valeurs absolues étant
inutilisables, les totaux de session sont cumulés à partir des écarts.

## Organisation

```
Sources/DeskMonitor/
├── main.swift              point d’entrée, barre des menus, actions de menu
├── WidgetWindow.swift      fenêtre sans bordure déplaçable + niveaux / ancrage aux coins
├── Probe.swift             mode texte de vérification --probe
├── Localization.swift      recherche des libellés
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift cadence des mesures : lecture en arrière-plan, publication sur le thread principal
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift mise en page du panneau
    ├── Sparkline.swift     courbe / courbe en miroir
    └── VisualEffectView.swift  fond dépoli

Resources/
├── en.lproj/               anglais (langue de base, la clé EST le texte anglais)
└── …                       zh-Hans / zh-Hant / ja / ko / de / fr / es / pt-BR / ru / it
```
