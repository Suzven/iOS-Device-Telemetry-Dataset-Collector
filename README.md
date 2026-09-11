# iOS Device Telemetry Dataset Collector

Нативный SwiftUI logger для iPhone/iPad, iOS 17+. SwiftData, UIKit, Foundation, Network, Core Motion; без сторонних зависимостей, сервера и ML.

## Запуск

1. Открыть `iOS-Device-Telemetry-Dataset-Collector.xcodeproj` в Xcode.
2. В Signing & Capabilities выбрать свою Team и при необходимости уникальный Bundle Identifier.
3. Выбрать подключённый iPhone и Run. На устройстве может потребоваться Developer Mode.
4. Выбрать 10 / 30 / 60 / 120 секунд (по умолчанию 60), нажать **Start collection**.
5. Разрешить Motion & Fitness по желанию. Отказ не прерывает сбор.
6. **Stop collection** сохраняет последний sample и закрывает сессию.
7. **Export all CSV** или **Export session CSV** открывает стандартный Share Sheet: Files, AirDrop и другие приложения.

Для реального датасета нужен физический iPhone: Simulator не воспроизводит настоящую батарею и Motion, а hardware identifier может быть архитектурой симулятора.

## Что именно записывается

Каждая строка основного CSV — действительное наблюдение. Нет activity labels, предсказаний, targets, rolling averages, нормализации и расчёта расхода батареи. Motion — только системные значения Core Motion, а не собственная классификация приложения.

| Колонки | Источник / формат |
| --- | --- |
| `sample_id`, `session_id` | UUID |
| `timestamp` | ISO 8601 UTC, миллисекунды, суффикс `Z` |
| `timestamp_unix` | Секунды Unix, дробная часть сохранена |
| `session_elapsed_seconds` | Разница реального wall-clock timestamp и начала сессии |
| `battery_level`, `battery_state` | UIDevice; 0…1 или пусто; unknown/unplugged/charging/full |
| `screen_brightness` | UIScreen связанной UIWindowScene; 0…1 или пусто |
| `thermal_state`, `low_power_mode` | ProcessInfo; nominal/fair/serious/critical/unknown, true/false |
| `network_type` | NWPathMonitor; wifi/cellular/wired/other/none/unknown |
| `network_expensive`, `network_constrained` | Флаги последнего NWPath; true/false или пусто до первого callback |
| `motion_activity` | stationary/walking/running/cycling/automotive/unknown |
| `motion_authorization` | authorized/denied/restricted/not_determined/unavailable/unknown |
| `motion_activity_timestamp` | Начало последнего полученного события Core Motion, ISO 8601 |
| `motion_stationary`, `motion_walking`, `motion_running`, `motion_cycling`, `motion_automotive` | Исходные независимые флаги Core Motion; пусто при отсутствии данных |
| `motion_confidence` | low/medium/high/unknown или пусто |
| `app_state` | active/inactive/background/unknown |
| `device_model` | `uname().machine`, например iPhone17,1 |
| `system_version` | UIDevice.systemVersion |
| `processor_count`, `active_processor_count`, `physical_memory` | ProcessInfo; количество ядер, байты физической RAM |
| `system_uptime` | Зарезервировано, всегда пусто — причина ниже |

Батарея `-1` не сохраняется. Пустые числовые поля читаются pandas как NaN. Запятые, кавычки, CR/LF экранируются по правилам CSV; UTF-8, строки CRLF, стабильный порядок колонок. Никаких локализованных десятичных запятых.

Core Motion допускает несколько одновременных true-флагов. При неоднозначности `motion_activity = unknown`, а исходные флаги сохранены. Timestamp события позволяет видеть возраст последнего состояния. После background кэш Motion и сети сбрасывается; до новых callbacks используются unknown/пустые поля. NWPath описывает маршрут приложения, а не объём трафика или качество интернет-соединения. Physical memory — объём RAM устройства, не потребление приложением. Brightness — системная настройка яркости, не измерение мощности дисплея.

Изменение системных часов может отразиться на elapsed/timestamps. Приложение не сглаживает и не исправляет эти raw значения.

## Ограничение `system_uptime`

`ProcessInfo.systemUptime` — публичный **required reason API**. Проверенные причины Apple 35F9.1 и 8FFB.1 не разрешают выгружать raw uptime с устройства. 3D61.1 относится к конкретному добровольному bug report, а не к исследовательскому датасету. Поэтому API не вызывается, поле nullable и CSV-колонка пустая. Приложение не декларирует ложную причину. Для такого использования нужно отдельное одобрение Apple; текущая реализация предпочитает требование допустимости API.

## Background и восстановление

Периодический сбор выполняется в active. При переходе в inactive/background сохраняются настоящее наблюдение и lifecycle event; таймер останавливается. Никаких background modes, аудио/геолокационных обходов или BGTask с обещанием точных интервалов нет.

Когда пользователь работает в других приложениях или блокирует телефон, **плотный непрерывный датасет не собирается**. После возврата сохраняются `app_became_active`, `sampling_resumed` и новый sample, затем запускается новый интервал. Незакрытая сессия восстанавливается и после force quit/перезагрузки устройства. Пропущенные измерения не создаются. Смена lifecycle может добавлять samples чаще выбранного интервала; первый и последний samples обязательны.

Lifecycle CSV содержит `session_started`, `app_became_inactive`, `app_entered_background`, `app_became_active`, `sampling_resumed`, `session_stopped`. События вне сессии не записываются. Force quit не гарантирует callback завершения: сессия намеренно остаётся открытой до восстановления и Stop.

Каждая запись выполняется в SwiftData transaction вместе со счётчиком samples и сопутствующими событиями. При ошибке сохранения выполняется rollback, сбор приостанавливается с видимым сообщением; доступны Retry sampling и повторный Stop. Невозможно обещать сохранность транзакции, которую ОС прервала до commit. При ошибке открытия базы нет подмены хранилищем в RAM и автоматического удаления данных.

## Экспорт

Share Sheet получает три файла:

- `device_telemetry_yyyy-MM-dd_HH-mm.csv` — samples всего датасета; для одной сессии `device_telemetry_session_<UUID>.csv`.
- `<base>_sessions.csv` — время начала/конца, количество samples, интервал и `optional_note`.
- `<base>_events.csv` — lifecycle events с session ID и timestamps.

Заметка редактируется в деталях сессии кнопкой **Save note** и никогда не включается в основной CSV. Пустой датасет экспортируется с заголовками. Samples и events читаются блоками по 500 строк; экспорт сериализован с записью на main actor для согласованного снимка базы. Очень большой экспорт может временно задерживать интерфейс и очередной sample — timestamps останутся реальными. CSV-файлы создаются в отдельном временном каталоге каждого экспорта и могут быть удалены iOS; сохраните их через Files/AirDrop.

База находится в `Application Support/Telemetry/dataset.store`, включая SQLite WAL/SHM. Размер на экране — размер этих файлов, а не оценка CSV. CloudKit отключён. Удаление приложения удаляет его локальный датасет, поэтому сохраняйте экспорты.

```python
import pandas as pd

df = pd.read_csv("device_telemetry_2026-09-10_16-45.csv")
df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True)
```

Дальнейшая подготовка данных и ML остаются за пределами приложения.

## Структура

- `Models/`: SwiftData-модели session/sample/event и transient MetricSnapshot.
- `Services/*MetricProvider.swift`: отдельные группы публичных метрик через MetricProvider.
- `TelemetryCollector`: жизненный цикл сбора и формирование измерений; провайдеры и часы можно внедрять.
- `DatasetStorage`: SwiftData, транзакции, выборки, размер локальных файлов.
- `CSVExporter`: форматирование без sensor APIs и доступа к базе.
- `DatasetExportService`: пакетное чтение и запись трёх CSV-файлов.
- `Views/`: dashboard, active collection, dataset, session details, Share Sheet.
- `Tests/`: CSV, lifecycle gaps, persistent recovery, фильтрация экспорта и rollback.

Для новой группы метрик добавьте MetricProvider и поля snapshot/model/schema. Изменения схемы уже выпущенной базы требуют продуманной миграции SwiftData.

## Проверка

```sh
xcodebuild -project iOS-Device-Telemetry-Dataset-Collector.xcodeproj \
  -scheme iOS-Device-Telemetry-Dataset-Collector \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

На физическом устройстве дополнительно проверить: отказ/разрешение Motion, смену Wi-Fi/cellular, зарядку, Low Power Mode, блокировку на несколько минут, force quit и восстановление, Save to Files/AirDrop. Изменение thermal state нельзя гарантированно воспроизвести в Simulator.

## Проверенные публичные API Apple

- [UIDevice batteryLevel](https://developer.apple.com/documentation/uikit/uidevice/batterylevel), [UIScreen brightness](https://developer.apple.com/documentation/uikit/uiscreen/brightness)
- [ProcessInfo](https://developer.apple.com/documentation/foundation/processinfo)
- [NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor)
- [CMMotionActivityManager и NSMotionUsageDescription](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager)
- [uname — iOS manual](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/uname.3.html)
- [App lifecycle](https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle)
- [Required reason API и ограничения uptime](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

PrivacyInfo.xcprivacy декларирует UserDefaults CA92.1 (интервал приложения) и FileTimestamp C617.1 (метаданные файлов собственной базы). Motion запрашивается только при начале/восстановлении сессии. Остальные сенсоры не требуют дополнительных пользовательских разрешений.
