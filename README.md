# FluidX

Жесты iPhone X для iPhone 7 на iOS 15.x (rootless). Аналог GesturesXV, но:
родной движок жестов SpringBoard вместо самописных распознавателей,
настройки внешнего вида полоски и починка анимации Пункта управления.

Пакет: `com.dolboebvaibcode.fluidx` · архитектура `iphoneos-arm64` · iOS 15.0+

---

## Что делает

| Жест | Действие |
|---|---|
| Свайп снизу вверх | Домой |
| Свайп снизу вверх + задержка | Многозадачность |
| Свайп по нижнему краю влево/вправо | Переключение между приложениями |
| Свайп сверху справа | Пункт управления |
| Кнопка Home | Продолжает работать как раньше |

Плюс настройки в **Настройки → FluidX**: включение, показ полоски,
высота/ширина полоски, свайп Пункта управления, фикс анимации, кнопка respring.

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

1. Перекинь `.deb` на телефон (iCloud Drive, Telegram «Избранное», почта, кабель).
2. Открой в **Filza** → тап по файлу → **Install** (или «Открыть в Sileo»).
3. Respring: из Sileo либо кнопкой в настройках твика.
4. Проверь: свайп снизу вверх должен уводить на домашний экран,
   снизу справа/слева — переключать приложения, сверху справа — Пункт управления.

Файлы на устройстве (rootless):

```
/var/jb/Library/TweakInject/FluidX.dylib
/var/jb/Library/TweakInject/FluidX.plist
/var/jb/Library/PreferenceBundles/FluidXPrefs.bundle/
/var/jb/Library/PreferenceLoader/Preferences/FluidX.plist
/var/jb/var/mobile/Library/Preferences/com.dolboebvaibcode.fluidx.plist
```

---

## Если что-то не так

| Симптом | Решение |
|---|---|
| Жесты не появились | Проверь, что твик загружен: `ls /var/jb/Library/TweakInject/`, затем respring |
| Полоска есть, свайпы не работают | Другой билд SpringBoard: пришли лог `log stream --predicate 'process == "SpringBoard"'`, подберём имена методов |
| Пункт управления открывается снизу | Включи «Свайп сверху справа» и сделай respring |
| Анимация Пункта управления дёргается | Переключи «Чинить анимацию Пункта управления» |
| SpringBoard в цикле | Загрузись без твиков / в safe mode, удали: `dpkg -r com.dolboebvaibcode.fluidx` |
| Настройки не появились | Не установлен PreferenceLoader — переустанови Sileo-пакет `preferenceloader` |
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
prefs/                       — бандл настроек (PSListController)
layout/                      — Root.plist, Info.plist, запись в PreferenceLoader
.github/workflows/build.yml  — сборка .deb
```

Локальная копия Theos и SDK 15.6 лежит в `../toolchain` — для чтения заголовков.
Собирать на Windows нельзя: Theos требует Linux/WSL/macOS, поэтому и используется CI.

---

## Дальше

- Тонкая настройка порогов жестов (скорость/дистанция) — нужны точные имена
  методов из SpringBoard твоей прошивки, подберём по логам.
- Настройка цвета/прозрачности полоски.
- Отдельные переключатели для «свайп вверх + задержка» и горизонтальных свайпов.
