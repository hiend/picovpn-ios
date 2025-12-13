# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Сборка проекта

Для сборки требуется полный Xcode (не только Command Line Tools):

```bash
# Открыть проект в Xcode
open PicoVPN.xcodeproj

# Сборка через командную строку (требует установленный Xcode)
xcodebuild -scheme PicoVPN -configuration Debug build
xcodebuild -scheme PicoTunnelExtension -configuration Debug build
xcodebuild -scheme PicoWidgetExtension -configuration Debug build
```

## Требования

- iOS 16.1+ (требуется для Dynamic Island API в PicoWidgetExtension)
- **Xcode 16.0+** (проект использует objectVersion 70 и PBXFileSystemSynchronizedRootGroup, несовместим с Xcode 15)
- Swift 5.0
- LibXray.xcframework

**Важно**: Если у вас Xcode 15.x, используйте GitHub Actions для сборки (см. `.github/workflows/build.yml`)

### Получение LibXray.xcframework

LibXray.xcframework исключен из git (.gitignore). Для его добавления:

```bash
# Скачать последний релиз LibXray
curl -L -o LibXray.xcframework.zip https://github.com/wanliyunyan/LibXray/releases/latest/download/LibXray.xcframework.zip

# Распаковать
unzip -q LibXray.xcframework.zip
rm LibXray.xcframework.zip
```

## Архитектура проекта

PicoVPN — iOS VPN клиент на базе Xray-core с тремя основными target:

### 1. PicoVPN (основное приложение)
- **Entry point**: `PicoApp.swift` (@main)
- **Менеджер приложения**: `PicoAppManager.swift` — центральный singleton для управления VPN, профилями и состоянием
- **UI**: SwiftUI views в директории `PicoVPN/Views/`
- **Хранилище**: UserDefaults для профилей, shared UserDefaults (App Group) для обмена данными с extension

### 2. PicoTunnelExtension (Network Extension)
- **Provider**: `PacketTunnelProvider.swift` — наследуется от `NEPacketTunnelProvider`
- **Функционал**:
  - Запускает Xray-core для обработки прокси-трафика
  - Поднимает Socks5Tunnel через Tun2SocksKit
  - Настраивает VPN tunnel с IPv4/IPv6
- **Взаимодействие с main app**: через App Group (`Common.groupName`)

### 3. PicoWidgetExtension
- WidgetKit extension для домашнего экрана

### Общие модули (Common/)

Shared код между target:

- **Config.swift**: Конфигурация Xray (inbounds, outbounds, routing, DNS, metrics)
- **Profile.swift**: Модель профиля VPN с поддержкой subscription URL
- **Inbound*.swift**: Определения входящих proxy (SOCKS, HTTP, VLESS, Trojan, Dokodemo)
- **Outbound*.swift**: Определения исходящих proxy (VLESS, VMess, Trojan, Shadowsocks, SOCKS, HTTP, Freedom, Blackhole)
- **Routing.swift**: Правила маршрутизации трафика
- **DNS.swift**: Настройки DNS
- **Dataset.swift**: Управление geoip/geosite данными
- **Metrics.swift**: Сбор статистики трафика
- **OnDemandRule.swift**: Правила автоматического подключения VPN

## Ключевые особенности архитектуры

### Управление профилями
- **PicoAppManager** управляет списком профилей (`[Profile]`)
- Каждый Profile содержит `Config` — полную конфигурацию Xray
- Профили сериализуются в JSON и сохраняются в UserDefaults
- Поддержка subscription: `Profile.fetchProxies()` загружает proxy из URL

### VPN Lifecycle
1. Пользователь выбирает профиль → `selectProfile()`
2. При старте → `start()` записывает config в `Common.configPath`
3. Порт SOCKS proxy сохраняется в shared UserDefaults
4. `NEVPNManager` запускает extension
5. Extension читает конфигурацию, запускает Xray и Socks5Tunnel
6. Остановка → `stop()` → extension вызывает `XrayStop()` и `Socks5Tunnel.quit()`

### Конфигурация Xray
- Базовая структура: `Config` с inbounds, outbounds, routing, dns
- **Inbounds**: точки входа (обычно SOCKS на localhost)
- **Outbounds**: upstream proxy серверы (VLESS, VMess, Trojan и т.д.)
- **Routing**: правила маршрутизации (domainStrategy, rules с geoip/geosite)
- Парсинг share links: `XrayConvertShareLinksToXrayJson()` из Xray framework

### Metrics/Stats
- Включаются через `Config.enableMetrics()`
- Добавляет Stats, Metrics, Policy с dokodemo-door inbound
- API для получения статистики доступен через `findMetricsPort()`

### Dependencies
- **LibXray.xcframework**: Core VPN engine на базе [LibXray](https://github.com/wanliyunyan/LibXray)
- **Tun2SocksKit**: SOCKS5 to TUN converter
- **CodeScanner**: QR code scanning для импорта конфигураций
- **SwiftUIX**: UI utilities

## App Group
Используется `Common.groupName` для shared storage между app и extension:
- Конфигурационный файл: `Common.configPath`
- Datasets: `Common.datasetsPath`
- Логи: `Common.accessLogPath`, `Common.errorLogPath`

## Важно при разработке

1. При изменении Config нужно вызвать `config.writeConfig()` для сохранения в файл
2. При изменении профиля активного подключения — использовать `restart()`
3. Проект не публикуется в App Store (см. README, только TestFlight)
4. Team ID: `2ZHWSJ25BU`, Bundle ID: `me.lsong.picovpn`

---

## История настройки проекта (декабрь 2024)

### Проблемы и решения при первой сборке

#### 1. Проблема версии Xcode
**Проблема**: Проект использует `objectVersion = 70` (Xcode 16.0+), локально установлен только Xcode 15.2
**Решение**: Создан GitHub Actions workflow (`.github/workflows/build.yml`) для автоматической сборки на `macos-15` runner с Xcode 16.4

#### 2. Отсутствие LibXray.xcframework
**Проблема**: LibXray.xcframework не включён в репозиторий (gitignore)
**Решение**: Workflow автоматически скачивает LibXray 25.12.8:
```bash
curl -L -o LibXray.xcframework.zip \
  https://github.com/wanliyunyan/LibXray/releases/download/25.12.8/LibXray.xcframework.zip
```

#### 3. Отсутствие module.modulemap
**Проблема**: LibXray 25.12.8 — статическая библиотека без модульной карты, Swift не мог найти модуль
**Решение**: Workflow создаёт `module.modulemap` для каждой платформы:
```bash
for platform in ios-arm64 ios-arm64_x86_64-simulator tvos-arm64 \
                tvos-arm64_x86_64-simulator macos-arm64_x86_64; do
  mkdir -p "LibXray.xcframework/$platform/Modules"
  cat > "LibXray.xcframework/$platform/Modules/module.modulemap" << 'EOF'
module LibXray {
    header "../Headers/libXray.h"
    export *
}
EOF
done
```

Затем обновляет `Info.plist` для указания `ModulesPath`:
```bash
for i in 0 1 2 3 4; do
  /usr/libexec/PlistBuddy -c \
    "Add :AvailableLibraries:$i:ModulesPath string Modules" \
    LibXray.xcframework/Info.plist 2>/dev/null || true
done
```

#### 4. Изменение API LibXray
**Проблема**: LibXray 25.12.8 использует новый CGo API вместо старого:
- Старый код: `XrayStart()`, `XrayStop()`, `XraySetEnv()`
- Новый API: `CGoRunXray()`, `CGoStopXray()`, `CGoXrayVersion()` с base64-кодированием

**Решение**: Созданы wrapper-функции в `Common/Common.swift` (строки 39-110):
```swift
import LibXray

// MARK: - LibXray Wrapper Functions

public func XraySetEnv(_ key: String, _ value: String) {
    // Environment setting is now handled differently
}

public func XrayStart(_ configPath: String) {
    do {
        let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let base64Config = configData.base64EncodedString()
        _ = CGoRunXray(strdup(base64Config))
    } catch {
        print("Failed to load config: \(error)")
    }
}

public func XrayStop() {
    _ = CGoStopXray()
}

public func XrayVersion() -> String {
    if let version = CGoXrayVersion() {
        return String(cString: version)
    }
    return "unknown"
}

// Аналогично для XrayConvertXrayJsonToShareLinks,
// XrayConvertShareLinksToXrayJson, XrayGetFreePort, XrayLoadGeoData
```

#### 5. Проблемы линковки
**Проблема**: LibXray был привязан только к PicoTunnelExtension и PicoWidgetExtension, но не к главному target PicoVPN, что вызывало ошибки линковки в AboutView.swift при вызове `XrayVersion()`

**Решение**: Добавлен LibXray.xcframework в PBXFrameworksBuildPhase главного target PicoVPN в `project.pbxproj`:
```
97DC74D02CA28BBF005BF0E8 /* Frameworks */ = {
    files = (
        97F9DA582D7A9B8800DF72A2 /* SwiftUIX in Frameworks */,
        974CB5672D59E7F600D0D25B /* libresolv.tbd in Frameworks */,
        973F95A12D5A4A6000D59EAF /* CodeScanner in Frameworks */,
        9785156B2D79601F003CEF6B /* LibXray.xcframework in Frameworks */,
    );
}
```

### Результат

✅ Проект успешно собирается на GitHub Actions
✅ Артефакт PicoVPN.ipa создаётся автоматически при каждом push в master
✅ Все три target (PicoVPN, PicoTunnelExtension, PicoWidgetExtension) успешно компилируются
✅ Workflow: https://github.com/hiend/picovpn-ios/actions

### Коммиты настройки

1. `019882b` - first commit (исходный репозиторий)
2. `543b3e1` - Create LibXrayShim with @_exported import (первая попытка wrapper)
3. `a87e09a` - Add LibXray wrapper functions directly in PacketTunnelProvider
4. `a354196` - Remove duplicate wrapper functions from PacketTunnelProvider
5. `464faa4` - Add LibXray.xcframework to PicoVPN target frameworks (финальное исправление)

### Файлы, изменённые для сборки

- `.github/workflows/build.yml` - CI/CD для автоматической сборки
- `Common/Common.swift` - добавлены wrapper-функции для LibXray CGo API
- `PicoVPN.xcodeproj/project.pbxproj` - добавлен LibXray в Frameworks главного target
- `.gitignore` - обновлён для LibXray.xcframework
- Удалены `import LibXray` из нескольких view-файлов (Config.swift, Inbound.swift, AboutView.swift, DatasetsView.swift)

### Рекомендации для будущих обновлений

1. **При обновлении LibXray**: проверить совместимость CGo API, возможно потребуется обновить wrapper-функции
2. **Для локальной сборки с Xcode 15.x**: невозможна, используйте GitHub Actions
3. **Для локальной сборки с Xcode 16+**: скачайте LibXray.xcframework вручную и выполните настройку module.modulemap локально (см. workflow)
4. **При добавлении новых target**: не забыть добавить LibXray.xcframework в Frameworks нового target
