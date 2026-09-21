# 데스크탑 모니터 DeskMonitor

[简体中文](../README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · **한국어** · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português (BR)](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

**CPU / GPU / 메모리 / 디스크 읽기·쓰기 / 네트워크 송수신**을 실시간으로 보여 주는
macOS 데스크탑 플로팅 위젯입니다.
네이티브 SwiftUI, 단일 프로세스, 의존성 없음. 모든 값을 시스템 저수준 API에서 읽으므로 **sudo가 필요 없습니다**.

## 빌드 및 실행

```bash
./build.sh              # 컴파일 + 번들 + 임시 서명
open DeskMonitor.app
```

`DeskMonitor --probe`는 5회분 샘플을 일반 텍스트로 출력합니다.
활성 상태 보기나 `top`과 대조해 검증할 때 쓰면 됩니다.

## 언어

인터페이스는 시스템 언어를 따릅니다. 모두 11가지:

简体中文 · 繁體中文 · English · 日本語 · 한국어 · Deutsch · Français · Español ·
Português (BR) · Русский · Italiano

그 밖의 언어는 영어로 대체됩니다.
「시스템 설정 › 일반 › 언어 및 지역 › 응용 프로그램」에서 이 앱에만 다른 언어를 지정할 수도 있습니다.

언어를 추가하려면 `Resources/en.lproj/`를 복사해 언어 코드로 이름을 바꾸고 번역한 뒤,
그 코드를 `Info.plist`의 `CFBundleLocalizations`에 추가하면 됩니다. 코드는 건드릴 필요가 없습니다.

## 사용법

Dock을 차지하지 않고 **기본적으로 메뉴 막대도 차지하지 않습니다**.
모든 설정은 **패널에서 마우스 오른쪽 버튼**을 눌러 나오는 메뉴에 있습니다.

| 동작 | 방법 |
|---|---|
| 위치 이동 | 패널 아무 곳이나 드래그 (위치는 기억되며, 드래그하면 스냅이 해제됩니다) |
| 스냅 위치 | 오른쪽 클릭 → 스냅 위치: 왼쪽 상단 / 오른쪽 상단 / 왼쪽 하단 / 오른쪽 하단 / 자유 배치 |
| 윈도우 레벨 | 오른쪽 클릭 → 윈도우 레벨: 바탕화면 위 / 일반 윈도우 / 항상 위에 |
| 새로 고침 간격 | 오른쪽 클릭 → 새로 고침 간격: 0.5 / 1 / 2 / 5초 |
| 불투명도 | 오른쪽 클릭 → 불투명도: 50% / 70% / 85% / 100% |
| 메뉴 막대 아이콘 | 오른쪽 클릭 → 메뉴 막대 아이콘 표시 (기본값 꺼짐) |
| 로그인 시 실행 | 오른쪽 클릭 → 로그인 시 실행 |
| 종료 | 오른쪽 클릭 → 종료 |

스냅할 모서리를 정해 두면 디스플레이를 바꾸거나 해상도를 변경해도 자동으로 다시 붙습니다.
메뉴 막대 아이콘이 꺼져 있으면 메뉴에 "패널 가리기"가 나오지 않습니다. 가리면 다시 불러올 입구가 없어지기 때문입니다.

기본 레벨은 "바탕화면 위"입니다. 배경 그림과 바탕화면 아이콘보다는 앞,
다른 앱 윈도우보다는 뒤에 놓여 데스크탑 위젯다운 느낌이 납니다.
항상 보이게 하려면 "항상 위에"로 바꾸세요.

## 데이터 출처

| 지표 | API | 설명 |
|---|---|---|
| CPU | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | 코어별 tick을 두 번 샘플링해 차이를 계산. 활성 상태 보기와 같은 출처 |
| GPU | IORegistry `IOAccelerator` → `PerformanceStatistics` | Apple Silicon에서는 root 불필요. sudo가 필요한 쪽은 `powermetrics` |
| 메모리 | `host_statistics64(HOST_VM_INFO64)` + `vm.swapusage` | 사용 중 = 앱 + 고정(wired) + 압축. 활성 상태 보기와 같은 기준 |
| 메모리 압력 | `kern.memorystatus_vm_pressure_level` | "사용 중"이 많다고 부족한 것은 아닙니다. 압력이 진짜 신호입니다 |
| 디스크 | IORegistry `IOBlockStorageDriver` → `Statistics` | 누적 바이트 수의 차이 ÷ 간격 = 실시간 읽기·쓰기 속도 |
| 용량 | `statfs` | 시동 디스크 여유 / 전체 용량. `df`와 같은 기준 |
| 네트워크 | `sysctl(NET_RT_IFLIST2)` → `if_data64` | 주 인터페이스 송수신 바이트의 차이. 인터페이스는 `SCDynamicStore`의 PrimaryInterface로 결정 |

잘못 읽기 쉬운 데이터 출처가 두 가지 있습니다.

**`IOAccelerator`의 `In use system memory`는 VRAM이 아닙니다.** 통합 메모리에서는 시스템 메모리를
따라가므로 512 GB 기기에서는 300 GB가 넘게 보고됩니다.
그래서 GPU 항목에는 사용률과 최근 최고치만 표시합니다.

**인터페이스 바이트 카운터는 하위 32비트만 유효합니다.** 이 앱이 `NET_RT_IFLIST2`에서 읽는
`ifi_ibytes` / `ifi_obytes`는 잘린 값입니다 (완전한 64비트는 Apple 서명 프로세스만 받습니다).
따라서 증분을 2³²로 나눈 나머지로 계산합니다. 한 번의 샘플링 간격에 4 GB를 넘지 않는 한 항상 정확합니다.
절댓값은 믿을 수 없으므로 세션 누계는 증분을 직접 쌓아서 구합니다.

## 구조

```
Sources/DeskMonitor/
├── main.swift              앱 진입점, 메뉴 막대, 메뉴 동작
├── WidgetWindow.swift      테두리 없는 드래그 가능 윈도우 + 레벨 / 모서리 스냅 정의
├── Probe.swift             --probe 텍스트 검증 모드
├── Localization.swift      문구 조회
├── Metrics/
│   ├── CPUMonitor.swift
│   ├── GPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── DiskMonitor.swift
│   ├── NetworkMonitor.swift
│   ├── MetricsEngine.swift 샘플링 스케줄. 백그라운드에서 읽고 메인 스레드에서 발행
│   └── Formatting.swift
└── Views/
    ├── DashboardView.swift 패널 레이아웃
    ├── Sparkline.swift     스파크라인 / 상하 대칭 스파크라인
    └── VisualEffectView.swift  반투명 유리 배경

Resources/
├── en.lproj/               영어 (기준 언어, 키가 곧 영어 문구)
└── …                       zh-Hans / zh-Hant / ja / ko / de / fr / es / pt-BR / ru / it
```
