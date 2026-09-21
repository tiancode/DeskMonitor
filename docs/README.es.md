# DeskMonitor

[简体中文](../README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · **Español** · [Português (BR)](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

Un widget flotante de escritorio para macOS que muestra en tiempo real
**CPU / GPU / memoria / lecturas y escrituras de disco / tráfico de red**.
SwiftUI nativo, un solo proceso, sin dependencias, todo leído mediante API de bajo nivel del
sistema: **no hace falta sudo**.

## Compilar y ejecutar

```bash
./build.sh              # compilar + empaquetar + firma ad hoc
open DeskMonitor.app
```

`DeskMonitor --probe` imprime 5 rondas de muestreo en texto plano, útil para contrastar con el
Monitor de Actividad o `top`.

## Idiomas

La interfaz sigue el idioma del sistema, 11 en total:

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Deutsch · Français · Español ·
Português (BR) · Русский · Italiano

El resto de idiomas recurre al inglés. También puedes asignar un idioma solo a esta app en
«Ajustes del Sistema › General › Idioma y región › Aplicaciones».

Para añadir un idioma basta con copiar `Resources/en.lproj/`, renombrarlo con el código de idioma,
traducirlo y añadir ese código a `CFBundleLocalizations` en `Info.plist`. No hay que tocar el código.

## Uso

La app no ocupa el Dock ni, **de manera predeterminada, la barra de menús**: todos los ajustes están
en el menú que aparece al **hacer clic derecho sobre el panel**.

| Acción | Cómo |
|---|---|
| Mover | Arrastra el panel por cualquier punto (la posición se recuerda y el anclaje se desactiva) |
| Posición de anclaje | Clic derecho → Posición de anclaje: Arriba izquierda / Arriba derecha / Abajo izquierda / Abajo derecha / Posición libre |
| Nivel de ventana | Clic derecho → Nivel de ventana: En el escritorio / Ventana normal / Siempre visible |
| Intervalo | Clic derecho → Intervalo de actualización: 0,5 / 1 / 2 / 5 s |
| Opacidad | Clic derecho → Opacidad: 50 % / 70 % / 85 % / 100 % |
| Icono en la barra de menús | Clic derecho → Mostrar icono en la barra de menús (desactivado por omisión) |
| Abrir al iniciar sesión | Clic derecho → Abrir al iniciar sesión |
| Salir | Clic derecho → Salir |

Una vez elegida una esquina, el panel vuelve a ella al cambiar de pantalla o de resolución.
Con el icono de la barra de menús desactivado, el menú no ofrece «Ocultar panel»: una vez oculto no
quedaría forma de recuperarlo.

El nivel predeterminado es «En el escritorio»: por encima del fondo de pantalla y de los iconos, por
debajo de las ventanas de otras apps. Así es como debe comportarse un widget de escritorio. Para
tenerlo siempre a la vista, cambia a «Siempre visible».

## Origen de los datos

| Métrica | API | Notas |
|---|---|---|
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Contadores de ticks por núcleo, diferencia entre dos muestras: la misma fuente del Monitor de Actividad |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | Sin root en Apple Silicon; quien exige sudo es `powermetrics` |
| Memoria | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | Usada = app + reservada (wired) + comprimida, igual que el Monitor de Actividad |
| Presión de memoria | `kern.memorystatus_vm_pressure_level` | Mucha memoria «usada» no implica apuro; la presión es la señal real |
| Disco | IORegistry `IOBlockStorageDriver` → `Statistics` | Diferencia de bytes acumulados ÷ intervalo = velocidad instantánea |
| Capacidad | `statfs` | Libre / total del disco de arranque, las mismas cifras que `df` |
| Red | `sysctl(NET_RT_IFLIST2)` → `if_data64` | Bytes de la interfaz principal, que determina PrimaryInterface de `SCDynamicStore` |

Dos fuentes fáciles de malinterpretar:

**`In use system memory` de `IOAccelerator` no es VRAM.** Con memoria unificada sigue a la memoria
del sistema y llega a informar más de 300 GB en una máquina de 512 GB. Por eso la fila de GPU solo
muestra el uso y el pico reciente.

**Los contadores de bytes de la interfaz solo llevan los 32 bits bajos.** Los `ifi_ibytes` /
`ifi_obytes` que esta app lee de `NET_RT_IFLIST2` vienen truncados: los 64 bits completos solo los
reciben los procesos firmados por Apple. Por eso los incrementos se calculan módulo 2³², lo que
sigue siendo correcto mientras un intervalo de muestreo no supere los 4 GB. Los valores absolutos no
son fiables, así que los totales de la sesión se acumulan a partir de los incrementos.

## Estructura

```
Sources/DeskMonitor/
├── main.swift              punto de entrada, barra de menús, acciones del menú
├── WidgetWindow.swift      ventana sin borde arrastrable + niveles / anclaje a esquinas
├── Probe.swift             modo de verificación por texto --probe
├── Localization.swift      búsqueda de textos
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift cadencia de muestreo: lectura en segundo plano, publicación en el hilo principal
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift diseño del panel
    ├── Sparkline.swift     minigráfico / minigráfico simétrico
    └── VisualEffectView.swift  fondo esmerilado

Resources/
├── en.lproj/               inglés (idioma base, la clave ES el texto en inglés)
└── …                       zh-Hans / zh-Hant / ja / ko / de / fr / es / pt-BR / ru / it
```
