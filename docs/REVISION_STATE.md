# Operation Tail: Logistics Command — Revision State & Checkpoint

**Дата среза:** 2026-11-24  
**Текущий статус:** Этапы 1–7 завершены и верифицированы; репозиторий готов к переносу на основной ПК через GitHub и переходу к Этапу 8.  
**Движок и стек:** Godot `4.7.2-stable` (`renderer/rendering_method="mobile"`), GDScript со строгой типизацией, целевое базовое разрешение `1280x800` (`window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`).  
**Точка входа и Autoload:** главная сцена `res://scenes/main_menu.tscn`, синглтон `AppState` (`res://scripts/core/app_state.gd`).

---

## 1. Завершённые этапы (Этапы 1–7)

### Этап 1 — Playable Vertical Slice
- Настроена структура Godot-проекта `game-logistics/` под `1280x800`, базовый граф (`data/scenario_01.json`), цикл тиков, перемещение колонн, снабжение секторов и базовый UI.

### Этап 2 — Штабная топографическая карта и визуальный стиль
- Бумажно-оливковый штабной стиль (`scripts/ui/tactical_theme.gd`), процедурный топографический фон (`assets/shaders/topo_map.gdshader` + `scripts/ui/topo_backdrop.gd`), кривые дороги и реки с вылетом за края, SVG-иконки Game-icons.net (`game-logistics/assets/icons/`), шрифты `PT Sans Narrow` и `IBM Plex Mono` (`game-logistics/assets/fonts/`).

### Этап 3 — Глубокая тактическая логистика
- Расширение ресурсов (`FUEL`, `AMMO`, `PROVISIONS`, `PARTS`), кастомизируемый ж/д эшелон по слотам, смена погоды (`CLEAR`, `RAIN`, `MUD`), повреждение и инженерный ремонт мостов, эвакуация раненых (`wounded`), радиограммы с переходом к узлу и автопаузой, артиллерийские дивизионы (`ARTILLERY`), поддерживающие фронт.

### Этап 4 — Оперативное масштабирование и подвижный фронт
- Нейтральный восточноевропейский сеттинг, большая скроллируемая карта с панорамированием/зумом (`scripts/ui/camera_controller.gd`), специализированный автопарк (`CARGO`, `TANKER`, `ENGINEER`), три режима приказов (`ONE_WAY_RETURN`, `REDEPLOY`, `LOOP`), двухфазное наступление (`BUILDUP` → `OFFENSIVE`), сдвиг линии фронта после захвата `OBJECTIVE`, разминирование, выбор целевой ж/д станции эшелона.

### Этап 5 — Темп, прозрачность UI и инструменты против сигнатуры
- Базовый темп симуляции на `1x`: `2.5` реальных секунды на тик (`10` игровых минут; `1` игровой час = `15` реальных секунд, интерполяция `tick_alpha` для плавного движения колонн), ночной режим маршрутов (`night_only`), активная маскировка складов, детализация прироста/охлаждения сигнатуры в инспекторе, запрет обычной выгрузки ресурсов на `JUNCTION` (разрешены только `REDEPLOY` и ремонт), ребаланс экономики.

### Этап 6 — Игровая оболочка и data-driven кампания
- Автозагружаемый менеджер `AppState` (`scripts/core/app_state.gd`) с профилями сохранений, настройками, историей миссий, командными очками (CP) и покупкой постоянных апгрейдов.
- Полный цикл экранов: `main_menu.tscn`, `settings_menu.tscn`, `campaign_select.tscn`, `campaign_hub.tscn`, `main.tscn`.
- Data-driven каталоги в `data/campaigns/` (`campaigns_index.json`, `upgrades.json`), модификаторы кампании (`SimTypes.CampaignModifiers`), второстепенные боевые задачи и дебрифинг; пройдены Операции 1 («Заслон») и 2 («Молот»).

### Этап 7 — Бронеподвоз, полевые склады, перевооружение и Операция 3 «Прорыв»
- **Простреливаемые дороги «последней мили» и БТР (`ARMORED`)**: флаг `frontline_danger` на прифронтовых рёбрах (динамически снимается при захвате связанной цели) и `frontline_interdiction_mult`; прочность колонн `hp` (`0..100`), капремонт `16 ч` при `0%`, авторемонт на `RAILHEAD`/`DEPOT`/`FIELD_DEPOT`, `-70%` риска ночью, автопауза `STRIKE_OR_DAMAGE`; бронеколонна `ARMORED` (`12т` любого груза, `90%` сопротивление урону, `0.4x` сигнатура, усиленная проходимость в грязь, заказ на эшелоне `TRUCK_ARMORED` и апгрейд `extra_armored`).
- **Полевые склады (`FIELD_DEPOT`)**: площадки `can_deploy_depot` на `JUNCTION`; развёртывание инженерной колонной с `25т PARTS` за `4 ч` (`24` тика) создаёт `FIELD_DEPOT` (`180/180/120/120/60т`, `loading_slots = 2`, `signature_mult = 0.75`); сворачивание за `3 ч` (`18` тиков) возвращает `10т PARTS`.
- **Перевооружение подразделений (`EQUIPMENT` → Ур. II)**: ресурс `EQUIPMENT`, платформа `EQUIPMENT_PLATFORM` на эшелоне (`2` слота, `30т`), доставка в `FRONT_SECTOR`/`ARTILLERY` и модернизация за `3 ч` (`18` тиков) до `equipment_tier = 2` (`+35%` эффективность удержания и штурма, `-20%` расхода БК и раненых); бейджи `★II` на карте и сохранение прогресса в `AppState` (`modernized_by_op`).
- **Операция 3 «Прорыв» (`data/scenario_breakthrough_03.json`)**: `26` узлов, `0` предстроенных передовых складов, `5` площадок `can_deploy_depot`, `3` укреплённых узла (`fortified_resistance: 1.25`), обязательная модернизация `>= 2` батальонов, 2 второстепенные цели.

---

## 2. Актуальное дерево файлов

```text
logistics_game/
├── .gitattributes
├── .gitignore
├── docs/
│   ├── GDD_MVP.md
│   └── REVISION_STATE.md
├── resources/                                  # Сырые архивы *.zip (исключены из Git)
└── game-logistics/
    ├── .editorconfig
    ├── icon.svg / icon.svg.import
    ├── project.godot
    ├── assets/
    │   ├── fonts/                              # 4 шрифта + .import
    │   │   ├── IBMPlexMono-Medium.ttf (+ .import)
    │   │   ├── IBMPlexMono-Regular.ttf (+ .import)
    │   │   ├── PTSansNarrow-Bold.ttf (+ .import)
    │   │   └── PTSansNarrow-Regular.ttf (+ .import)
    │   ├── icons/                              # 35 SVG-иконок Game-icons.net + .import
    │   │   ├── allied-star.svg, ammo-box.svg, apc.svg, artillery-shell.svg,
    │   │   ├── barracks-tent.svg, binoculars.svg, broken-wall.svg, bulldozer.svg,
    │   │   ├── clockwise-rotation.svg, compass.svg, convergence-target.svg,
    │   │   ├── crosshair.svg, crossroad.svg, fast-forward-button.svg,
    │   │   ├── flatbed-covered.svg, gas-pump.svg, hazard-sign.svg, heavy-rain.svg,
    │   │   ├── jerrycan.svg, medicines.svg, military-ambulance.svg, mortar.svg,
    │   │   ├── oil-drum.svg, pause-button.svg, play-button.svg, radar-sweep.svg,
    │   │   ├── satellite.svg, steam-locomotive.svg, sunrise.svg, tank.svg,
    │   │   ├── teller-mine.svg, tower-flag.svg, walkie-talkie.svg,
    │   │   ├── warehouse.svg, wrench.svg
    │   └── shaders/
    │       └── topo_map.gdshader (+ .uid)
    ├── data/
    │   ├── scenario_01.json
    │   ├── scenario_defense_01.json
    │   ├── scenario_offensive.json
    │   ├── scenario_breakthrough_03.json
    │   └── campaigns/
    │       ├── campaigns_index.json
    │       └── upgrades.json
    ├── scenes/
    │   ├── main_menu.tscn
    │   ├── settings_menu.tscn
    │   ├── campaign_select.tscn
    │   ├── campaign_hub.tscn
    │   └── main.tscn
    ├── scripts/
    │   ├── core/
    │   │   └── app_state.gd (+ .uid)
    │   ├── sim/                                # Чистое ядро без Node2D/Control
    │   │   ├── campaign_data.gd (+ .uid)
    │   │   ├── convoy.gd (+ .uid)
    │   │   ├── scenario_loader.gd (+ .uid)
    │   │   ├── sim_engine.gd (+ .uid)
    │   │   ├── sim_types.gd (+ .uid)
    │   │   └── world_graph.gd (+ .uid)
    │   └── ui/
    │       ├── camera_controller.gd (+ .uid)
    │       ├── campaign_hub.gd (+ .uid)
    │       ├── campaign_select.gd (+ .uid)
    │       ├── hud.gd (+ .uid)
    │       ├── main.gd (+ .uid)
    │       ├── main_menu.gd (+ .uid)
    │       ├── map_view.gd (+ .uid)
    │       ├── menu_backdrop.gd (+ .uid)
    │       ├── settings_menu.gd (+ .uid)
    │       ├── tactical_theme.gd (+ .uid)
    │       └── topo_backdrop.gd (+ .uid)
    └── tests/
        ├── headless_sim_test.gd (+ .uid)
        └── headless_campaign_test.gd (+ .uid)
```

---

## 3. Архитектурные инварианты

1. **Изоляция ядра симуляции (`scripts/sim/`)**: все классы симуляции наследуются от `RefCounted` и не зависят от `Node2D`, `Control` или сцен. Любая новая игровая механика сначала реализуется и тестируется в `scripts/sim/`.
2. **Строгая типизация GDScript (Godot 4.7.2)**: явные типы переменных, параметров и возвращаемых значений. **Запрещено** использовать `:=` на нетипизированных `Variant`-вызовах (`Dictionary.get()`, `JSON.parse_string()` и т.п.).
3. **Data-driven JSON-конфигурация**: карты, волны интенсивности, расписание эшелонов, кампании, брифинги, второстепенные цели и апгрейды задаются в `game-logistics/data/` без хардкода конкретных названий в UI.
4. **Границы карты `map_bounds` и вылеты графики**: игровая область определяется в сценарии (`map_bounds`), а фон (`TopoBackdrop`: `MAP_ORIGIN = (-400, -400)`, `MAP_SIZE = (3100, 2050)`), реки, ж/д пути и линия фронта рисуются с вылетом за края `map_bounds`, чтобы при панорамировании и зуме (`CameraController`) не обнажались пустые поля.
5. **Единый UI и адаптивность `1280x800`**: все экраны используют `tactical_theme.gd` и обязаны корректно читаться в базовом окне `1280x800` (`canvas_items`, `expand`).
6. **Версионирование переносимости**: файлы `*.import` и `*.uid` обязательно хранятся в Git; переводы строк для всех текстовых/данных/Godot-файлов зафиксированы как `LF` через `.gitattributes`.

---

## 4. Точный каталог данных и сущностей

### Сценарии (`game-logistics/data/`)
| Файл | ID / Название | Режим | Длит. | Размер карты (`map_bounds`) | Ключевые особенности |
|---|---|---|---|---|---|
| `scenario_01.json` | `scenario_01` — Операция «Тыл»: 72 часа | Legacy MVP (Этап 1) | 72 ч | — (экран `1280x800`) | 11 узлов, ранний vertical slice (`FUEL`, `AMMO`) |
| `scenario_defense_01.json` | `scenario_defense_01` — Операция «Заслон» | `DEFENSE` | 48 ч | `1600x960` | 15 узлов, 4 сектора, 2 склада, `frontline_interdiction_mult: 0.45`, пробой моста |
| `scenario_offensive.json` | `scenario_offensive` — Операция «Молот» | `OFFENSIVE` (2 фазы, Ф2 с `36ч`) | 120 ч | `2200x1250` | 6 секторов, 2 АДН, 3 цели, `frontline_interdiction_mult: 0.55`, 2 ж/д станции |
| `scenario_breakthrough_03.json` | `scenario_breakthrough_03` — Операция «Прорыв» | `OFFENSIVE` (2 фазы, Ф2 с `30ч`) | 120 ч | `2400x1350` | 26 узлов, 0 передовых `DEPOT`, 5 площадок `can_deploy_depot`, `frontline_interdiction_mult: 0.75`, `required_modernized_units: 2` |

### Кампании (`game-logistics/data/campaigns/campaigns_index.json`)
- **`eastern_front` — Кампания 1: «Восточный рубеж»** (`coming_soon: false`, старт: `60 CP`, стартовый флот: `5 CARGO`, `3 TANKER`, `1 ENGINEER`, `0 ARMORED`):
  1. `op_01_zaslon` — Операция 1: «Заслон» (`DEFENSE`, 48 ч, `100 CP` + 2 доп. цели по `40 CP`: `no_depot_strikes`, `evac_80_wounded`)
  2. `op_02_molot` — Операция 2: «Операция Молот» (`OFFENSIVE`, 120 ч, `160 CP` + 2 доп. цели по `50 CP`: `fast_capture_100h`, `min_integrity_40`)
  3. `op_03_proryv` — Операция 3: «Прорыв» (`OFFENSIVE`, 120 ч, `200 CP` + 2 доп. цели по `60 CP`: `deploy_2_depots`, `zero_convoy_losses`)
- **`winter_cauldron` — Кампания 2: «Зимний котёл»** (`coming_soon: true`, заготовка под зимние механики).

### Апгрейды кампании (`game-logistics/data/campaigns/upgrades.json`, 7 шт.)
1. `extra_cargo` (`80 CP`): `+1` бортовая колонна `CARGO` (`bonus_cargo_convoys: 1`)
2. `extra_tanker` (`80 CP`): `+1` топливозаправщик `TANKER` (`bonus_tanker_convoys: 1`)
3. `extra_engineer` (`90 CP`): `+1` инженерная рота `ENGINEER` (`bonus_engineer_convoys: 1`)
4. `extended_train` (`110 CP`): `+1` вагон в эшелоне (`bonus_train_slots: 1`)
5. `camo_nets` (`95 CP`): `-20%` к росту сигнатуры складов и станций (`depot_signature_growth_mult: 0.80`)
6. `heavy_suspension` (`85 CP`): `+15%` скорости по грунту и распутице (`dirt_mud_speed_mult: 1.15`)
7. `extra_armored` (`100 CP`): `+1` бронегруппа подвоза `ARMORED` (`bonus_armored_convoys: 1`)

### Сущности ядра (`scripts/sim/sim_types.gd`, `scripts/sim/convoy.gd`)
- **Ресурсы (`ResourceType`, 5 типов + учёт раненых):** `FUEL`, `AMMO`, `PROVISIONS`, `PARTS`, `EQUIPMENT` (плюс эвакуируемые `wounded` на узлах/колоннах).
- **Типы узлов (`NodeType`, 7 типов):** `RAILHEAD`, `DEPOT`, `FIELD_DEPOT`, `JUNCTION`, `ARTILLERY`, `FRONT_SECTOR`, `OBJECTIVE`.
- **Типы колонн (`ConvoyType`, 4 типа):**
  - `CARGO` — `30 т`, погрузка `2` тика, все типы грузов (вкл. `EQUIPMENT`).
  - `TANKER` — `40 т`, погрузка `1` тик, только `FUEL` (`FUEL` / `MIXED`).
  - `ENGINEER` — `26 т`, погрузка `2` тика, `PARTS` / `EQUIPMENT` / `MIXED`, ремонт мостов, разминирование, развёртывание/сворачивание `FIELD_DEPOT`.
  - `ARMORED` — `12 т`, погрузка `1` тик, любые грузы, `90%` защита от обстрела, `0.4x` сигнатура, высокая проходимость в распутицу.
- **Режимы приказов (`OrderMode`, 3 режима):** `ONE_WAY_RETURN`, `REDEPLOY`, `LOOP`.

---

## 5. Headless-тесты и статус проверки

Универсальные команды запуска из корня репозитория (`godot` — бинарник Godot `4.7.2-stable`, на текущем Steam Deck: `/run/media/deck/5c56616b-d1e0-47bd-a755-5e8d67348e08/Projects/Godot_v4.7.2-stable_linux.x86_64`):

```bash
# 1. Реимпорт ресурсов (опционально после клонирования на новом ПК)
godot --headless --path game-logistics --import --quit

# 2. Юнит-тесты чистого ядра и механик Этапов 5 и 7
godot --headless --path game-logistics --script res://tests/headless_sim_test.gd

# 3. Тест кампании, апгрейдов, Операций 1–3 и смок-инстанциации всех 5 .tscn сцен
godot --headless --path game-logistics --script res://tests/headless_campaign_test.gd

# 4. Проверка чистого запуска проекта
godot --headless --path game-logistics --quit-after 10
```

**Статус последнего прогона (2026-11-24):**
- `headless_sim_test.gd` — **PASS** (`ALL STAGE 5 & STAGE 7 HEADLESS SIMULATION CHECKS PASSED.`, exit code `0`).
- `headless_campaign_test.gd` — **PASS** (`ALL STAGE 6 & 7 CAMPAIGN & SCENE CHECKS PASSED.`, exit code `0`; Операция 3 «Прорыв» завершена победой за `66.7 ч`, `Objectives=3/3`, `Modernized=2`, `FieldDepots=2`, `Disabled=0`, `Delivered=2876т`, все 5 сцен загружены и инстанциированы).
- `--quit-after 10` — **PASS** (exit code `0`, без ошибок парсинга и выполнения).

---

## 6. Next Planned Stage (Stage 8)

Планируемый этап фокусируется на визуальной атмосфере, кастомной картографии и звуке:

1. **Утилита экспорта чертежа карты для генерации PNG-подложек**: выгрузка точной схемы сценария (границы `map_bounds`, дороги, узлы, реки, высоты/ориентиры) в эталонное изображение/чертёж для внешней генерации высокодетализированных PNG-подложек.
2. **Загрузчик кастомных фонов карты**: поддержка опциональной PNG/WebP-подложки в описании сценария / UI с безопасным fallback на текущий процедурный `TopoBackdrop` (`topo_map.gdshader`).
3. **Обновление иконок**: доработка/замена ряда SVG-иконок и тактических пиктограмм на карте и в HUD под единую визуальную детализацию.
4. **2D VFX на карте**:
   - ночное освещение и конусы фар движущихся колонн в тёмное время суток;
   - эффект дождя при `Weather.RAIN` / `Weather.MUD`;
   - дрейфующие тени облаков над топографической картой;
   - дым от пожаров/ударов/разрушений и визуальный скан разведки (импульс/свип по зоне обнаружения).
5. **`AudioManager` и звук**: новый Autoload/сервис для эмбиента фронта и погоды, тактильных звуков штабного UI (клики, телеграф/радиограммы, отдача приказов), фоновой музыки и привязки к ползункам громкости в `settings_menu.gd` / `AppState`.
