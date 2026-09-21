# DeskMonitor

[简体中文](../README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · **Português (BR)** · [Русский](README.ru.md) · [Italiano](README.it.md)

Um widget flutuante de mesa para macOS que mostra em tempo real
**CPU / GPU / memória / leitura e gravação de disco / tráfego de rede**.
SwiftUI nativo, um único processo, sem dependências, tudo lido por APIs de baixo nível do sistema —
**sem sudo**.

## Compilar e executar

```bash
./build.sh              # compilar + empacotar + assinatura ad hoc
open DeskMonitor.app
```

`DeskMonitor --probe` imprime 5 rodadas de amostragem em texto puro, útil para conferir com o
Monitor de Atividade ou o `top`.

## Idiomas

A interface acompanha o idioma do sistema, 11 no total:

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Deutsch · Français · Español ·
Português (BR) · Русский · Italiano

Os demais idiomas recaem no inglês. Também dá para definir um idioma só para este app em
"Ajustes do Sistema › Geral › Idioma e Região › Aplicativos".

Para acrescentar um idioma, copie `Resources/en.lproj/`, renomeie com o código do idioma, traduza e
adicione esse código a `CFBundleLocalizations` no `Info.plist`. Nada de mexer no código.

## Uso

O app não ocupa o Dock nem, **por padrão, a barra de menus** — todos os ajustes ficam no menu que
aparece ao **clicar com o botão direito no painel**.

| Ação | Como |
|---|---|
| Mover | Arraste o painel por qualquer ponto (a posição é lembrada e o encaixe é desativado) |
| Posição de encaixe | Botão direito → Posição de encaixe: Superior esquerdo / Superior direito / Inferior esquerdo / Inferior direito / Posição livre |
| Nível da janela | Botão direito → Nível da janela: Na Mesa / Janela normal / Sempre visível |
| Intervalo | Botão direito → Intervalo de atualização: 0,5 / 1 / 2 / 5 s |
| Opacidade | Botão direito → Opacidade: 50% / 70% / 85% / 100% |
| Ícone na barra de menus | Botão direito → Mostrar ícone na barra de menus (desligado por padrão) |
| Abrir ao iniciar sessão | Botão direito → Abrir ao iniciar sessão |
| Encerrar | Botão direito → Encerrar |

Escolhido um canto, o painel volta para ele depois de trocar de monitor ou de resolução.
Com o ícone da barra de menus desligado, o menu não oferece "Ocultar painel" — uma vez oculto não
haveria como trazê-lo de volta.

O nível padrão é "Na Mesa": acima do fundo de tela e dos ícones, atrás das janelas dos outros apps.
É assim que um widget de mesa deve se comportar. Para mantê-lo sempre à vista, mude para
"Sempre visível".

## Origem dos dados

| Métrica | API | Observações |
|---|---|---|
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Contagem de ticks por núcleo, diferença entre duas amostras — a mesma fonte do Monitor de Atividade |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | Sem root no Apple Silicon; quem pede sudo é o `powermetrics` |
| Memória | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | Usada = app + reservada (wired) + comprimida, igual ao Monitor de Atividade |
| Pressão de memória | `kern.memorystatus_vm_pressure_level` | Muita memória "usada" não significa aperto; a pressão é o sinal real |
| Disco | IORegistry `IOBlockStorageDriver` → `Statistics` | Diferença dos bytes acumulados ÷ intervalo = velocidade instantânea |
| Capacidade | `statfs` | Livre / total do disco de inicialização, os mesmos números do `df` |
| Rede | `sysctl(NET_RT_IFLIST2)` → `if_data64` | Bytes da interface principal, definida pelo PrimaryInterface do `SCDynamicStore` |

Duas fontes fáceis de ler errado:

**O `In use system memory` do `IOAccelerator` não é VRAM.** Com memória unificada ele acompanha a
memória do sistema e chega a informar mais de 300 GB numa máquina de 512 GB. Por isso a linha da GPU
mostra apenas a utilização e o pico recente.

**Os contadores de bytes da interface só carregam os 32 bits baixos.** Os `ifi_ibytes` /
`ifi_obytes` que este app lê de `NET_RT_IFLIST2` vêm truncados — os 64 bits completos só chegam a
processos assinados pela Apple. Os incrementos são então calculados módulo 2³², o que continua
correto enquanto um intervalo de amostragem transportar menos de 4 GB. Os valores absolutos não
servem, então os totais da sessão são acumulados a partir dos incrementos.

## Estrutura

```
Sources/DeskMonitor/
├── main.swift              ponto de entrada, barra de menus, ações do menu
├── WidgetWindow.swift      janela sem borda arrastável + níveis / encaixe nos cantos
├── Probe.swift             modo de verificação em texto --probe
├── Localization.swift      busca de textos
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift ritmo da amostragem: leitura em segundo plano, publicação na thread principal
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift layout do painel
    ├── Sparkline.swift     minigráfico / minigráfico espelhado
    └── VisualEffectView.swift  fundo fosco

Resources/
├── en.lproj/               inglês (idioma base, a chave É o texto em inglês)
└── …                       zh-Hans / zh-Hant / ja / ko / de / fr / es / pt-BR / ru / it
```
