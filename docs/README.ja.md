# デスクトップモニタ DeskMonitor

[简体中文](../README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · **日本語** · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (BR)](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

**CPU / GPU / メモリ / ディスク読み書き / ネットワーク送受信**をリアルタイムに表示する
macOS のデスクトップ常駐ウィジェットです。
ネイティブ SwiftUI、単一プロセス、依存なし。すべて OS の低レベル API から取得し、**sudo は不要**です。

## ビルドと実行

```bash
./build.sh              # ビルド + バンドル + アドホック署名
open DeskMonitor.app
```

`DeskMonitor --probe` はサンプリング 5 回分をプレーンテキストで出力します。
アクティビティモニタや `top` と突き合わせて検証するのに便利です。

## 言語

インターフェイスはシステムの言語に従います。全 11 種類：

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Deutsch · Français · Español ·
Português (BR) · Русский · Italiano

それ以外の言語は英語にフォールバックします。
「システム設定 › 一般 › 言語と地域 › アプリケーション」でこのアプリだけ別の言語に設定することもできます。

言語を追加するには `Resources/en.lproj/` をコピーして言語コードにリネームし、翻訳したうえで、
そのコードを `Info.plist` の `CFBundleLocalizations` に加えるだけです。コードの変更は不要です。

## 操作

Dock には入らず、**メニューバーにも既定では入りません**。設定はすべて**パネル上で右クリック**して開くメニューにあります。

| 操作 | 方法 |
|---|---|
| 移動 | パネルのどこでもドラッグ（位置は記憶され、ドラッグするとスナップは解除されます） |
| スナップ位置 | 右クリック → スナップ位置：左上 / 右上 / 左下 / 右下 / 自由配置 |
| ウインドウレベル | 右クリック → ウインドウレベル：デスクトップ上 / 通常ウインドウ / 常に最前面 |
| 更新間隔 | 右クリック → 更新間隔：0.5 / 1 / 2 / 5 秒 |
| 不透明度 | 右クリック → 不透明度：50% / 70% / 85% / 100% |
| メニューバーアイコン | 右クリック → メニューバーアイコンを表示（既定はオフ） |
| ログイン時に起動 | 右クリック → ログイン時に起動 |
| 終了 | 右クリック → 終了 |

スナップ先の角を決めておくと、ディスプレイや解像度が変わっても自動で貼り直します。
メニューバーアイコンがオフのときはメニューに「パネルを隠す」が出ません。隠すと呼び戻す入口がなくなるためです。

既定のレベルは「デスクトップ上」です。壁紙とデスクトップのアイコンより手前、
ほかのアプリのウインドウより奥——デスクトップウィジェットらしい挙動になります。
常に見えるようにしたい場合は「常に最前面」に切り替えてください。

## データソース

| 指標 | API | 備考 |
|---|---|---|
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | コアごとの tick を 2 回サンプリングして差分。アクティビティモニタと同じ出どころ |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | Apple Silicon では root 不要。sudo が要るのは `powermetrics` のほう |
| メモリ | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | 使用中 = アプリ + 確保 (wired) + 圧縮。アクティビティモニタと同じ定義 |
| メモリプレッシャー | `kern.memorystatus_vm_pressure_level` | 「使用中」が多いこと自体は逼迫を意味しません。プレッシャーが本当の信号です |
| ディスク | IORegistry `IOBlockStorageDriver` → `Statistics` | 累積バイト数の差分 ÷ 間隔 = 実時間の読み書き速度 |
| 容量 | `statfs` | 起動ディスクの空き / 総容量。`df` と同じ基準 |
| ネットワーク | `sysctl(NET_RT_IFLIST2)` → `if_data64` | 主インターフェイスの送受信バイト数の差分。インターフェイスは `SCDynamicStore` の PrimaryInterface で決まります |

読み違えやすいデータソースが 2 つあります。

**`IOAccelerator` の `In use system memory` は VRAM ではありません。** ユニファイドメモリでは
システムメモリに連動するため、512 GB のマシンでは 300 GB 超と報告されます。
そのため GPU の行には使用率と直近のピークだけを表示しています。

**インターフェイスのバイトカウンタは下位 32 ビットしか有効ではありません。**
このアプリが `NET_RT_IFLIST2` から読む `ifi_ibytes` / `ifi_obytes` は切り詰められた値です
（完全な 64 ビットを受け取れるのは Apple 署名のプロセスだけ）。
そこで差分は 2³² を法として計算しています。1 回のサンプリング間隔の通信量が 4 GB 未満なら常に正しい値になります。
絶対値は信用できないため、セッション累計は差分を自分で積み上げています。

## 構成

```
Sources/DeskMonitor/
├── main.swift              アプリのエントリ、メニューバー、メニュー動作
├── WidgetWindow.swift      ボーダーレスのドラッグ可能ウインドウ + レベル / 四隅スナップの定義
├── Probe.swift             --probe テキスト検証モード
├── Localization.swift      文言のルックアップ
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift サンプリング制御。バックグラウンドで取得しメインスレッドで公開
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift パネルのレイアウト
    ├── Sparkline.swift     スパークライン / 上下対称スパークライン
    └── VisualEffectView.swift  すりガラスの背景

Resources/
├── en.lproj/               英語（基準言語。キーがそのまま英語の文言）
└── …                       zh-Hans / zh-Hant / ja / ko / de / fr / es / pt-BR / ru / it
```
