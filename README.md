# FluidX

Жесты iPhone X для iPhone 7 на iOS 15.x (rootless). Аналог GesturesXV, но:
родной движок жестов SpringBoard вместо самописных распознавателей,
настройки внешнего вида полоски и починка анимации Пункта управления.

Пакет: `com.dolboebvaibcode.fluidx` · архитектура `iphoneos-arm64` · iOS 15.0+

---

> ⚠️ **Дисклеймер**
>
> Твик написан **нейросетью (ИИ)** в учебных целях. Автор **не несёт никакой
> ответственности за ваш iPhone** и за любые последствия установки: зависания,
> циклический respring, потерю данных, необходимость перепрошивки или
> восстановления устройства, потерю гарантии.
>
> Всё, что вы делаете, — **на ваш страх и риск**. Перед установкой сделайте
> резервную копию и убедитесь, что умеете откатываться (удалить пакет через
> Sileo/Zebra, при необходимости — `Restore RootFS` в Dopamine).
>
> Твик не связан с Apple, не одобрен Apple и использует приватные API
> (`SBHomeGestureSettings`, `SBFHomeGrabberSettings` и др.), поэтому
> работоспособность на конкретной версии iOS не гарантируется.

---

## Что делает

| Жест | Действие |
|---|---|
| Свайп снизу вверх | Домой |
| Свайп снизу вверх + задержка | Многозадачность |
| Свайп по нижнему краю влево/вправо | Переключение между приложениями |
| Свайп сверху справа | Пункт управления |
| Кнопка Home | Продолжает работать как раньше |

Плюс **отдельное приложение FluidX** с иконкой на рабочем столе (не в
Настройках — там iOS 15 упорно не отдавала наш бандл настроек):

| Раздел | Что настраивается |
|---|---|
| Жесты iPhone X | включение, показ домашней полоски |
| Домашняя полоска | высота, ширина, прозрачность, цвет в HEX |
| Анимации | скорость интерфейса SpringBoard (0.5–2.0) |
| Производительность | режим «без блюра» — легче GPU на A10 |
| Пункт управления | свайп сверху справа, фикс анимации |
| Применение | respring, сброс настроек |
| О твике | GitHub, Telegram [@angel_gtag](https://t.me/angel_gtag), лог сборки |

Приложение пишет тот же plist, что читает твик
(`/var/mobile/Library/Preferences/com.dolboebvaibcode.fluidx.plist`), поэтому
изменения применяются сразу, без перезапуска приложения. Размер полоски и
цвет — после respring.

---

## Почему это плавнее аналогов

1. **Никаких сторонних `UIGestureRecognizer`.** Твик только включает уже
   существующий в SpringBoard движок `SBHomeGestureSettings` /
   `SBFHomeGrabberSettings`, который Apple использует на iPhone X+. Все
   анимации, интерполяции и отклик — системные.
2. **Нулевое вмешательство по умолчанию.** Размеры полоски переопределяются
   только если пользователь реально сдвинул слайдер (0 = системное значение),
   поэтому «растягивание» полоски при свайпе не ломается.
3. **Хуки только на геттеры/сеттеры настроек**, а не на покадровые методы
   (`layoutSubviews`, анимационные батчи). Нет работы в hot path кадров.
4. **Настройки кэшируются** в статические переменные и перечитываются только
   по Darwin-уведомлению, а не при каждом вызове хука.

Для сравнения: GesturesXV подменяет «железо» (`BSPlatform homeButtonType`,
`MGCopyAnswer`) и потом вручную чинит клавиатуру, Reachability, кнопки на
локскрине и CC — отсюда кривые анимации и «квадратная» полоска. FluidX так не делает.

---

## Джейлбрейк

### Dopamine 3 (рекомендуется)

Dopamine 3.0+ поддерживает **A8–A13 на iOS 15.0–18.7.1 и 26.0–26.0.1**,
работает только в rootless-режиме — как раз наш случай. Ставится через
[TrollStore](https://ios.cfw.guide/installing-dopamine-trollstore) или
[без него](https://ios.cfw.guide/installing-dopamine), официальный сайт:
<https://ellekit.space/dopamine/>.

Если приложение скажет, что 15.8.8 не поддерживается — используй **palera1n**
(эксплойт checkm8, A8–A11, iOS 15.0+). На Windows palera1n запускается
с загрузочной флешки [Palen1x](https://palera.in/download).

> ⚠️ Сайты «jailbreak online без компьютера» — мошенничество.

Для установки `.deb` понадобится **Sileo** (идёт с джейлбрейком) и желательно
**Filza**. Твик использует **ElleKit** — он уже установлен джейлбрейком.

---

## Сборка `.deb`

Сборка идёт в GitHub Actions, локально ничего ставить не нужно.

1. Создай аккаунт на <https://github.com> и репозиторий (можно приватный).
2. Залей папку `project` — проще всего через [GitHub Desktop](https://desktop.github.com):
   *File → Add local repository → Publish repository*.
3. В репозитории: **Actions → Build tweak → Run workflow**.
4. Через ~5 минут скачай артефакт **FluidX-deb** (zip) и распакуй `.deb`.

Через терминал (git уже установлен):

```powershell
cd "C:\Users\angelss\Documents\Default Project\ios-tweak\project"
git remote add origin https://github.com/ТВОЙ_ЛОГИН/FluidX.git
git push -u origin main
```

---

## Установка на iPhone

**Готовая сборка (без GitHub-аккаунта):**

```
https://github.com/vaibcode-dev/FluidX/raw/ci-logs/com.dolboebvaibcode.fluidx_0.3.0-beta_iphoneos-arm64.deb
```

Страница релиза (там же `.deb` прикреплён файлом):
<https://github.com/vaibcode-dev/FluidX/releases>

Открой ссылку в Safari на iPhone → «Скачать» → в Filza открой файл → **Install**.
(Ветка `ci-logs` — публичная, там же лежит `build.log` последней сборки.)

```text
/var/jb/Applications/FluidX.app
/var/jb/Library/MobileSubstrate/DynamicLibraries/FluidX.dylib + FluidX.plist
/var/mobile/Library/Preferences/com.dolboebvaibcode.fluidx.plist
```

> Текущая версия — **0.3.0-beta**: помечена как pre-release, потому что твик
> ещё не проверен на всех прошивках iOS 15.

Либо вручную:

1. Перекинь `.deb` на телефон (iCloud Drive, Telegram «Избранное», почта, кабель).
2. Открой в **Filza** → тап по файлу → **Install** (или «Открыть в Sileo»).
3. На рабочем столе появится приложение **FluidX** (его регистрирует `postinst`
   через `uicache`). Если иконки нет — запусти в Filza
   `/var/jb/usr/bin/uicache -p /var/jb/Applications/FluidX.app` и подожди пару секунд.
4. Открой приложение, выставь настройки, нажми **Respring**.
5. Проверь: свайп снизу вверх должен уводить на домашний экран,
   снизу справа/слева — переключать приложения, сверху справа — Пункт управления.

Файлы на устройстве (rootless):

```
/var/jb/Library/MobileSubstrate/DynamicLibraries/FluidX.dylib
/var/jb/Library/MobileSubstrate/DynamicLibraries/FluidX.plist
/var/jb/Applications/FluidX.app
/var/mobile/Library/Preferences/com.dolboebvaibcode.fluidx.plist
```

### Если приложения FluidX нет на рабочем столе

Приложение ставится в `/var/jb/Applications/FluidX.app` и регистрируется
`uicache` в `postinst`. Если иконки нет:

1. Проверь, что пакет установлен: **Sileo → Установленные → FluidX**,
   версия должна быть `0.3.0-beta` (не `0.2.x`).
2. Открой Filza → `/var/mobile/FluidX-install.txt` — там лог `postinst`:
   что нашлось, что удалилось и с каким кодом отработал `uicache`.
3. Запусти регистрацию вручную: в Filza открой
   `/var/jb/usr/bin/uicache` (или через терминал:
   `uicache -p /var/jb/Applications/FluidX.app`), затем подожди 5–10 секунд.
4. Если и это не помогло — пришли в Telegram файл `/var/mobile/FluidX-install.txt`
   и скриншот рабочего стола.

Раздел **FluidX в Настройках** из версий 0.2.x больше не нужен: `postinst`
удаляет старые файлы PreferenceLoader и перезапускает Настройки.

---

## Как всё проверять

### 1. Аккаунт GitHub

Открой `https://github.com/ТВОЙ_ЛОГИН` — профиль должен открываться, логин видно
в адресе и в правом верхнем углу. Если страница 404 — аккаунт ещё не создан.

### 2. Локальный репозиторий

```powershell
cd "C:\Users\angelss\Documents\Default Project\ios-tweak\project"
powershell -ExecutionPolicy Bypass -File tools\check-repo.ps1
```

Скрипт покажет ветку, последние коммиты, привязан ли `origin`, есть ли
незакоммиченные изменения и все ли обязательные файлы на месте.

### 3. Репозиторий на GitHub

`https://github.com/ТВОЙ_ЛОГИН/FluidX` — в списке файлов должны быть `Tweak.x`,
`Makefile`, `control` и папка `.github/workflows`. Хэш последнего коммита на сайте
должен совпадать с локальным (`git log --oneline -1`).

### 4. Сборка

Вкладка **Actions** → слева **Build tweak** → запуск с зелёной галочкой.
Шаги внутри запуска: `Checkout`, `Install Theos`, `Add iOS 15.6 SDK`, `Build .deb`,
`Upload .deb`. Красный крестик = открой лог упавшего шага.

### 5. Артефакт

Внизу страницы запуска — **Artifacts → FluidX-deb**. Внутри zip лежит
`com.dolboebvaibcode.fluidx_0.3.0-beta_iphoneos-arm64.deb`.

Проверка файла до установки:

```powershell
python tools\inspect_deb.py "путь\к\com.dolboebvaibcode.fluidx_0.3.0-beta_iphoneos-arm64.deb"
```

Скрипт покажет package id, архитектуру, пути `/var/jb`, тип Mach-O и фильтр
SpringBoard. Если пишет «всё в порядке» — пакет собран правильно.

### 6. Телефон

```sh
dpkg -l | grep fluidx                  # пакет установлен
ls -l /var/jb/Library/MobileSubstrate/DynamicLibraries/   # FluidX.dylib + FluidX.plist
```

На рабочем столе должно появиться приложение **FluidX**, а в его настройках —
все ползунки и тумблеры.

---

## Если что-то не так

| Симптом | Решение |
|---|---|
| Жесты не появились | Проверь, что твик загружен: `ls /var/jb/Library/MobileSubstrate/DynamicLibraries/`, затем respring |
| Настройки не применяются | Открой FluidX, нажми **Respring**; проверь, что в приложении стоит «Включить жесты» |
| Полоска есть, свайпы не работают | Другой билд SpringBoard: пришли лог `log stream --predicate 'process == "SpringBoard"'`, подберём имена методов |
| Пункт управления открывается снизу | Включи «Свайп сверху справа» и сделай respring |
| Анимация Пункта управления дёргается | Переключи «Чинить анимацию Пункта управления» |
| SpringBoard в цикле | Загрузись без твиков / в safe mode, удали: `dpkg -r com.dolboebvaibcode.fluidx` |
| Нет иконки FluidX | Запусти `uicache -p /var/jb/Applications/FluidX.app`, см. `/var/mobile/FluidX-install.txt` |
| Actions упал | Перезапусти workflow, затем пришли лог упавшего шага |

Логи:

```sh
log stream --predicate 'process == "SpringBoard"' --level debug
```

---

## Структура проекта

```
Tweak.x                      — хуки SpringBoard
Makefile                     — arm64, iOS 15.0+, rootless
control                      — метаданные пакета
app/                         — приложение настроек (UIKit, без PreferenceLoader)
app/Resources/Info.plist     — Info.plist приложения + иконки
layout/DEBIAN/postinst       — uicache + чистка старых файлов 0.2.x
.github/workflows/build.yml  — сборка .deb
```

Локальная копия Theos и SDK 15.6 лежит в `../toolchain` — для чтения заголовков.
Собирать на Windows нельзя: Theos требует Linux/WSL/macOS, поэтому и используется CI.

---

## Дальше

- Тонкая настройка порогов жестов (скорость/дистанция) — нужны точные имена
  методов из SpringBoard твоей прошивки, подберём по логам.
- Отдельные переключатели для «свайп вверх + задержка» и горизонтальных свайпов.
- Пресеты цвета полоски вместо ручного ввода HEX.
