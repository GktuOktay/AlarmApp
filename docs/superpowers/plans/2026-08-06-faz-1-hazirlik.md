# Faz 1 — Hazırlık (Sprint 0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> Orkestrasyon: `2026-08-06-alarmapp-faz-plani.md`

**Goal:** Çalışan Xcode workspace iskeleti: `AlarmAppCore` SPM + iOS + watchOS target’lar, boş SwiftData şema iskeleti, CI, açık kaynak dosyaları — iş mantığı / ekran yok.

**Architecture:** `docs/06` §2 layout; Core UI’sız; her iki app `import AlarmAppCore`.

**Tech Stack:** Xcode 15+, Swift Package Manager, SwiftData, SwiftLint, GitHub Actions.

## Global Constraints

Ana plan Global Constraints + bu fazda **domain algoritması yazılmaz** (CreateAlarmGroup vb. Faz 2). Ürün kararları onayı Faz 2’den önce zorunlu; Faz 1’i engellemez.

**Doc refs:** `04` Faz 0, `06` §2–§7, `05` CI gate, `02` ADR-1/ADR-4, `03` §1 (şimdilik boş container).

---

### Task 1: Repo iskeleti + MIT LICENSE + README

**Files:**
- Create: `LICENSE`
- Create: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `SECURITY.md`
- Create: `CHANGELOG.md`
- Create: `.gitignore`

**Interfaces:**
- Consumes: `docs/06` §1, §7
- Produces: kök OSS dosyaları; sonraki task’lar bu layout’a oturur

- [ ] **Step 1: `.gitignore` oluştur**

```
# Xcode
DerivedData/
*.xcuserstate
xcuserdata/
*.xccheckout
*.moved-aside
*.hmap
*.ipa
*.dSYM.zip
*.dSYM
timeline.xctimeline
playground.xcworkspace

# SPM
.build/
Packages/
Package.resolved
*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/

# macOS
.DS_Store

# Fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output
```

- [ ] **Step 2: MIT `LICENSE` ekle** (yıl 2026, proje adı AlarmApp; copyright sahibi kullanıcı adıyla)

- [ ] **Step 3: `README.md` — kurulum tek adım**

İçerik zorunlu başlıklar:
1. Tek cümle konumlandırma (PRD: *"Alarmlarını grupla, uyandığında bilek seni anlasın, gerisini kapatsın."*)
2. Gereksinimler: Xcode 15+, iOS 17 / watchOS 10, Apple Developer
3. Kurulum: `open AlarmApp.xcworkspace`
4. Mimari özeti: üç parçalı (Core / iOS / Watch) — `docs/02` referansı
5. Doküman indeksi: `docs/00` … `docs/07`

- [ ] **Step 4: `CONTRIBUTING.md` iskeleti** — Conventional Commits, `main`/`develop`/`feature/*`, PR’da Core için iki platform notu (`06` §4)

- [ ] **Step 5: `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`** — kısa iskelet; CHANGELOG’da `## Unreleased` + `### Added` altında “Project scaffolding”

- [ ] **Step 6: Commit**

```bash
git add LICENSE README.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md CHANGELOG.md .gitignore
git commit -m "$(cat <<'EOF'
docs: add open-source skeleton and gitignore

EOF
)"
```

---

### Task 2: `AlarmAppCore` Swift Package iskeleti

**Files:**
- Create: `AlarmAppCore/Package.swift`
- Create: `AlarmAppCore/Sources/AlarmAppCore/AlarmAppCore.swift`
- Create: `AlarmAppCore/Sources/AlarmAppCore/Domain/.gitkeep` (veya boş `Placeholder.swift`)
- Create: `AlarmAppCore/Sources/AlarmAppCore/Data/ModelContainerFactory.swift`
- Create: `AlarmAppCore/Sources/AlarmAppCore/Connectivity/.gitkeep`
- Create: `AlarmAppCore/Tests/AlarmAppCoreTests/AlarmAppCoreTests.swift`

**Interfaces:**
- Consumes: `06` §2 klasör yapısı; `02` katman kuralı
- Produces: `public enum AlarmAppCoreModule` (veya paket adı export); `ModelContainerFactory.makeInMemory()` → `ModelContainer`

- [ ] **Step 1: `Package.swift` yaz**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlarmAppCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "AlarmAppCore", targets: ["AlarmAppCore"])
    ],
    targets: [
        .target(
            name: "AlarmAppCore",
            path: "Sources/AlarmAppCore"
        ),
        .testTarget(
            name: "AlarmAppCoreTests",
            dependencies: ["AlarmAppCore"],
            path: "Tests/AlarmAppCoreTests"
        )
    ]
)
```

- [ ] **Step 2: Boş public giriş noktası**

`AlarmAppCore/Sources/AlarmAppCore/AlarmAppCore.swift`:

```swift
import Foundation

/// Shared domain/data/connectivity package for iOS and watchOS.
public enum AlarmAppCoreModule {
    public static let version = "0.0.1"
}
```

- [ ] **Step 3: SwiftData boş container factory (şema henüz entity’siz)**

`ModelContainerFactory.swift`:

```swift
import Foundation
import SwiftData

public enum ModelContainerFactory {
    /// In-memory container for tests and early scaffolding.
    public static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Schema([]), configurations: [configuration])
    }
}
```

Not: Gerçek `@Model` tipleri Faz 2 Task’larında `03` §1’den kopyalanır. Bu fazda sadece migration altyapısı için factory + boş `Schema([])`.

- [ ] **Step 4: Smoke test**

`AlarmAppCoreTests.swift`:

```swift
import XCTest
import SwiftData
@testable import AlarmAppCore

final class AlarmAppCoreTests: XCTestCase {
    func testModuleVersion() {
        XCTAssertFalse(AlarmAppCoreModule.version.isEmpty)
    }

    func testInMemoryContainerCreates() throws {
        let container = try ModelContainerFactory.makeInMemory()
        XCTAssertNotNil(container)
    }
}
```

- [ ] **Step 5: Çalıştır — beklenen PASS**

```bash
cd AlarmAppCore && swift test
```

Expected: `Test Suite 'All tests' passed` (veya Swift Testing eşdeğeri yeşil).

- [ ] **Step 6: Anti-pattern grep**

```bash
rg "import SwiftUI" AlarmAppCore/Sources || true
```

Expected: eşleşme yok.

- [ ] **Step 7: Commit**

```bash
git add AlarmAppCore
git commit -m "$(cat <<'EOF'
chore: scaffold AlarmAppCore Swift package

EOF
)"
```

---

### Task 3: Xcode workspace — iOS + Watch target’lar

**Files:**
- Create: `AlarmApp-iOS/AlarmApp_iOSApp.swift` (veya Xcode’un ürettiği App dosyası)
- Create: `AlarmApp-iOS/ContentView.swift` (geçici placeholder)
- Create: `AlarmApp-Watch/AlarmApp_WatchApp.swift`
- Create: `AlarmApp-Watch/ContentView.swift`
- Create: `AlarmApp.xcodeproj` / `AlarmApp.xcworkspace` (Xcode GUI veya `xcodegen` — tercihen Xcode File → New Project, sonra SPM local package ekle)

**Interfaces:**
- Consumes: local package `AlarmAppCore`
- Produces: her iki target’ta `import AlarmAppCore` derlenir

- [ ] **Step 1: Xcode’da multiplatform / iOS App + Watch App Companion oluştur**

Manuel adımlar (ajan: kullanıcı Xcode kullanıyorsa talimat; CI’da proje dosyası commit’lenmeli):
1. iOS App (SwiftUI, SwiftData kapalı şimdilik — Core’dan gelecek)
2. Watch App target ekle (companion)
3. File → Add Package Dependencies → Add Local → `AlarmAppCore/`
4. Her iki target’ın Frameworks’üne `AlarmAppCore` ekle
5. Deployment: iOS 17.0, watchOS 10.0

- [ ] **Step 2: Placeholder View’larda Core import doğrula**

iOS `ContentView.swift` örneği:

```swift
import SwiftUI
import AlarmAppCore

struct ContentView: View {
    var body: some View {
        Text("AlarmApp \(AlarmAppCoreModule.version)")
    }
}
```

Watch tarafında aynı import + Text.

- [ ] **Step 3: Derle**

```bash
xcodebuild -workspace AlarmApp.xcworkspace -scheme AlarmApp-iOS -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -workspace AlarmApp.xcworkspace -scheme AlarmApp-Watch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

Expected: `BUILD SUCCEEDED` (simülatör adı ortama göre ayarlanabilir; `xcrun simctl list` ile doğrula).

- [ ] **Step 4: Commit** (`.xcodeproj`, `.xcworkspace`, app kaynakları)

```bash
git add AlarmApp.xcworkspace AlarmApp.xcodeproj AlarmApp-iOS AlarmApp-Watch
git commit -m "$(cat <<'EOF'
chore: add iOS and watchOS app targets wired to AlarmAppCore

EOF
)"
```

---

### Task 4: SwiftLint + GitHub Actions CI

**Files:**
- Create: `.swiftlint.yml`
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `05` CI gate, `04` Sprint 0 CI satırı
- Produces: PR’da lint + `swift test` (+ mümkünse `xcodebuild test`)

- [ ] **Step 1: `.swiftlint.yml` minimal**

```yaml
included:
  - AlarmAppCore
  - AlarmApp-iOS
  - AlarmApp-Watch
excluded:
  - .build
  - DerivedData
disabled_rules:
  - trailing_whitespace
line_length:
  warning: 120
  error: 200
```

- [ ] **Step 2: `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  core-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: SwiftLint
        run: |
          if which swiftlint >/dev/null; then swiftlint lint --strict; else
            brew install swiftlint
            swiftlint lint --strict
          fi
      - name: AlarmAppCore tests
        run: cd AlarmAppCore && swift test
      # xcodebuild test: workspace commit edildikten sonra aç
      # - name: iOS build
      #   run: xcodebuild -workspace AlarmApp.xcworkspace -scheme AlarmApp-iOS -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- [ ] **Step 3: Lokal lint (opsiyonel)**

```bash
swiftlint lint
```

- [ ] **Step 4: Commit**

```bash
git add .swiftlint.yml .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
ci: add SwiftLint and GitHub Actions core test workflow

EOF
)"
```

---

### Task 5: Faz 1 doğrulama checklist

- [ ] **Step 1: Layout `06` §2 ile eşleşiyor mu?**

```bash
ls -la
ls AlarmAppCore/Sources/AlarmAppCore
```

Expected: `AlarmAppCore/`, `AlarmApp-iOS/`, `AlarmApp-Watch/`, `docs/`, `LICENSE`, `README.md` (workspace/xcodeproj Task 3 sonrası).

- [ ] **Step 2: Core test yeşil**

```bash
cd AlarmAppCore && swift test
```

- [ ] **Step 3: SwiftUI Core’da yok**

```bash
rg "import SwiftUI" AlarmAppCore/Sources
```

Expected: no matches.

- [ ] **Step 4: Domain use case dosyası yok (YAGNI)**

```bash
rg -l "CreateAlarmGroup|HandleWakeEvent" AlarmAppCore || true
```

Expected: boş (bunlar Faz 2).

- [ ] **Step 5: CHANGELOG Unreleased güncelle** — scaffolding maddeleri

- [ ] **Step 6: Final commit (gerekirse)**

```bash
git add CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs: mark Sprint 0 scaffolding complete in changelog

EOF
)"
```

---

## Faz 1 sonrası handoff

1. Ürün kararları onaylandı mı? → `docs/superpowers/specs/2026-08-06-urun-kararlari.md`
2. Onay sonrası: Faz 2 detay planı yaz (`writing-plans`) — Domain modeller `03` §1’den kopya, `CreateAlarmGroup` test-first (`05` tabloları).
3. Bu chat’te Faz 2’ye kayma — kullanıcı açıkça istemedikçe hayır.
