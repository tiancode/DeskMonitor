# 桌面監視器 DeskMonitor

[简体中文](../README.md) · **繁體中文** · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (BR)](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

macOS 桌面懸浮小工具，即時顯示 **CPU / GPU / 記憶體 / 硬碟讀寫 / 網路上下行**。
原生 SwiftUI，單一行程，無相依套件，全部資料走系統底層 API——**不需要 sudo**。

## 建置與執行

```bash
./build.sh              # 編譯 + 打包 + 臨時簽章
open DeskMonitor.app
```

`DeskMonitor --probe` 可以用純文字印出 5 輪取樣，方便和活動監視器 / `top` 對照校驗。

## 語言

介面跟隨系統語言，共 11 種：

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Deutsch · Français · Español ·
Português (BR) · Русский · Italiano

其餘語言回退到英文。也可以在「系統設定 › 一般 › 語言與地區 › 應用程式」裡單獨指定本 App 的語言。

新增一種語言只要複製一份 `Resources/en.lproj/`，改成對應的語言代碼翻譯完，
再把該代碼加進 `Info.plist` 的 `CFBundleLocalizations` 即可，程式碼不用動。

## 操作

App 不佔 Dock，**預設也不佔選單列**——所有設定都在**面板上按右鍵**跳出的選單裡。

| 操作 | 方式 |
|---|---|
| 移動位置 | 直接拖面板任意處（位置自動記住；拖過就自動解除吸附） |
| 吸附位置 | 右鍵 → 吸附位置：左上角 / 右上角 / 左下角 / 右下角 / 自由擺放 |
| 視窗層級 | 右鍵 → 視窗層級：貼在桌面上 / 一般視窗 / 永遠最上層 |
| 更新間隔 | 右鍵 → 更新間隔：0.5 / 1 / 2 / 5 秒 |
| 不透明度 | 右鍵 → 不透明度：50% / 70% / 85% / 100% |
| 選單列圖像 | 右鍵 → 顯示選單列圖像（預設關） |
| 登入時啟動 | 右鍵 → 登入時啟動 |
| 結束 | 右鍵 → 結束 |

選定吸附角落後，換螢幕或改解析度都會自動貼回去。
關掉選單列圖像時，選單裡不提供「隱藏面板」——藏了就沒有入口叫回來了。

預設層級是「貼在桌面上」——浮在桌布和桌面圖像之上，會被其他 App 的視窗蓋住，
這就是桌面小工具的手感。想讓它永遠看得見就切「永遠最上層」。

## 資料來源

| 指標 | API | 說明 |
|---|---|---|
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | 讀每核 tick 計數，兩次取樣求差，和活動監視器同源 |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | Apple Silicon 上免 root；`powermetrics` 才需要 sudo |
| 記憶體 | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | 已用 = 應用程式 + 已佔用(wired) + 已壓縮，口徑對齊活動監視器 |
| 記憶體壓力 | `kern.memorystatus_vm_pressure_level` | 「已用」高不等於吃緊，壓力才是真訊號 |
| 硬碟 | IORegistry `IOBlockStorageDriver` → `Statistics` | 累計位元組數求差 ÷ 間隔 = 即時讀寫速度 |
| 容量 | `statfs` | 啟動磁碟可用 / 總容量，口徑與 `df` 一致 |
| 網路 | `sysctl(NET_RT_IFLIST2)` → `if_data64` | 主網路卡收發位元組求差；網路卡由 `SCDynamicStore` 的 PrimaryInterface 決定 |

兩個容易讀錯的資料來源：

**`IOAccelerator` 的 `In use system memory` 不是顯示記憶體。** 統一記憶體架構下它跟著系統記憶體走，
在 512 GB 機器上會報出 300+ GB。GPU 一欄因此只顯示使用率和近期峰值。

**網路卡位元組計數只有低 32 位元有效。** 本 App 從 `NET_RT_IFLIST2` 讀到的
`ifi_ibytes` / `ifi_obytes` 是截斷值（Apple 簽章的行程才拿得到完整 64 位元）。
增量因此按模 2³² 計算——單次取樣間隔內流量不超過 4 GB 就始終正確；
絕對值不可信，「累計」只能自己從增量累加。

## 結構

```
Sources/DeskMonitor/
├── main.swift              App 進入點、選單列、選單動作
├── WidgetWindow.swift      無邊框可拖曳視窗 + 層級 / 四角吸附定義
├── Probe.swift             --probe 文字校驗模式
├── Localization.swift      文案查表
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift 取樣排程，背景取數、主執行緒發布
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift 面板佈局
    ├── Sparkline.swift     折線圖 / 雙向鏡像折線圖
    └── VisualEffectView.swift  毛玻璃背景

Resources/
├── en.lproj/               英文（基準語言，鍵即英文原文）
└── …                       zh-Hans / zh-Hant / ja / ko / de / fr / es / pt-BR / ru / it
```
