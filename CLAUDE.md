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

- iOS 16.6+
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
