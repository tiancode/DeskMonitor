# 桌面监视器 DeskMonitor

macOS 桌面悬浮小组件，实时显示 **CPU / GPU / 内存 / 硬盘读写 / 网络上下行**。
原生 SwiftUI，单进程，无依赖，全部数据走系统底层 API——**不需要 sudo**。

## 构建与运行

```bash
./build.sh              # 编译 + 打包 + 临时签名
open DeskMonitor.app
```

`DeskMonitor --probe` 可以用纯文本打印 5 轮采样，方便和活动监视器 / `top` 对照校验。

## 语言

界面跟随系统语言，目前提供简体中文和英文，其余语言回退到英文。
也可以在「系统设置 › 语言与地区 › 应用程序」里单独给本应用指定语言。

新增一种语言只要复制一份 `Resources/en.lproj/`，改成对应的语言代码译完，
再把该代码加进 `Info.plist` 的 `CFBundleLocalizations` 即可，代码不用动。

## 操作

应用不占 Dock，**默认也不占菜单栏**——所有设置都在**面板上右键**弹出的菜单里。

| 操作 | 方式 |
|---|---|
| 移动位置 | 直接拖面板任意处（位置自动记住；拖动后自动解除吸附） |
| 吸附位置 | 右键 → 吸附位置：左上角 / 右上角 / 左下角 / 右下角 / 自由摆放 |
| 窗口层级 | 右键 → 窗口层级：贴在桌面上 / 普通窗口 / 始终置顶 |
| 刷新间隔 | 右键 → 刷新间隔：0.5 / 1 / 2 / 5 秒 |
| 不透明度 | 右键 → 不透明度：50% / 70% / 85% / 100% |
| 菜单栏图标 | 右键 → 显示菜单栏图标（默认关） |
| 开机启动 | 右键 → 开机自动启动 |
| 退出 | 右键 → 退出 |

选定吸附角落后，换显示器或改分辨率都会自动贴回去。
关掉菜单栏图标时菜单里不提供「隐藏面板」——藏了就没有入口叫回来了。

默认层级是「贴在桌面上」——浮在壁纸和桌面图标之上，会被其它 App 的窗口盖住，
这就是桌面小组件的手感。想让它永远可见就切「始终置顶」。

## 数据来源

| 指标 | API | 说明 |
|---|---|---|
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | 读每核 tick 计数，两次采样求差，和活动监视器同源 |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | Apple Silicon 上免 root；`powermetrics` 才需要 sudo |
| 内存 | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | 已用 = 应用内存 + 联动(wired) + 已压缩，口径对齐活动监视器 |
| 内存压力 | `kern.memorystatus_vm_pressure_level` | 「已用」高不等于吃紧，压力才是真信号 |
| 硬盘 | IORegistry `IOBlockStorageDriver` → `Statistics` | 累计字节数求差 ÷ 间隔 = 实时读写速度 |
| 容量 | `statfs` | 启动盘可用 / 总容量，口径与 `df` 一致 |
| 网络 | `sysctl(NET_RT_IFLIST2)` → `if_data64` | 主网卡收发字节求差；网卡由 `SCDynamicStore` 的 PrimaryInterface 决定 |

两个容易读错的数据源：

**`IOAccelerator` 的 `In use system memory` 不是显存。** 统一内存架构下它跟着系统内存走，
在 512 GB 机器上会报出 300+ GB。GPU 一栏因此只显示占用率和近期峰值。

**网卡字节计数只有低 32 位有效。** 本应用从 `NET_RT_IFLIST2` 读到的
`ifi_ibytes` / `ifi_obytes` 是截断值（Apple 签名的进程才拿到完整 64 位）。
增量因此按模 2³² 计算——单次采样间隔内流量不超过 4 GB 就始终正确；
绝对值不可信，「累计」只能自己从增量累加。

## 结构

```
Sources/DeskMonitor/
├── main.swift              应用入口、菜单栏、菜单动作
├── WidgetWindow.swift      无边框可拖拽窗口 + 层级 / 四角吸附定义
├── Probe.swift             --probe 文本校验模式
├── Localization.swift      文案查表，键即英文原文
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift 采样调度，后台取数、主线程发布
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift 面板布局
    ├── Sparkline.swift     折线图 / 双向镜像折线图
    └── VisualEffectView.swift  毛玻璃背景

Resources/
├── en.lproj/               英文（基准语言）
└── zh-Hans.lproj/          简体中文
```
