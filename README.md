# MyTweak — твик для iPhone 7 / iOS 15.8.8 (rootless)

Готовый каркас твика на [Theos](https://theos.dev): сборка идёт в GitHub Actions,
поэтому в Windows ничего устанавливать не нужно — только скачать готовый `.deb`.

---

## 0. Важно про джейлбрейк

**Dopamine твоему iPhone 7 не подойдёт.** Он официально поддерживает только
устройства с процессором **arm64e (A12 и новее)** и iOS **15.0–15.4.1**.
iPhone 7 — это arm64 (A10), а iOS 15.8.8 сильно новее.

Правильный вариант для iPhone 7 на iOS 15 — **palera1n** (эксплойт checkm8,
поддерживает A8–A11 и iOS 15.0+). Он умеет как раз **rootless**-режим,
под который сделан этот проект.

На Windows у palera1n нет нативной поддержки, поэтому используется загрузочная
флешка **Palen1x**:

1. Возьми USB-флешку от 2 ГБ (содержимое будет стёрто).
2. Скачай образ Palen1x с официального сайта <https://palera.in/download>.
3. Запиши образ на флешку через [Rufus](https://rufus.ie) (режим DD) или balenaEtcher.
4. Перезагрузи ПК с флешки (F12 / Boot Menu), Secure Boot лучше отключить.
5. В меню запусти `palera1n`, выбери **rootless**, подключи iPhone кабелем
   и следуй подсказкам (телефон нужно будет перевести в DFU).
6. После джейлбрейка на телефоне появятся **Sileo** и **ElleKit**.

> ⚠️ Сайты вида «jailbreak online без компьютера» — мошенничество, ничего не скачивай оттуда.
> Официальные адреса: <https://palera.in> и <https://github.com/palera1n/palera1n>.

---

## 1. Что лежит в проекте

| Файл | Назначение |
|---|---|
| `Tweak.x` | код твика (Logos). **Тут ты и будешь писать** |
| `Makefile` | настройки сборки: arm64, iOS 15.0+, rootless |
| `control` | описание пакета для Sileo (имя, версия, зависимости) |
| `.github/workflows/build.yml` | сборка `.deb` на серверах GitHub |

Сейчас в `Tweak.x` стоит демо-хук: через 3 секунды после запуска SpringBoard
появляется окно «Твик загружен ✅». Это проверка, что вся цепочка работает.

---

## 2. Аккаунт GitHub и загрузка проекта

1. Зарегистрируйся на <https://github.com> (бесплатно).
2. Установи [GitHub Desktop](https://desktop.github.com) — с ним не нужен терминал.
3. В GitHub Desktop: **File → Add local repository** → выбери папку `project`.
   Он предложит создать репозиторий — согласись.
4. Нажми **Publish repository**. Имя — например `ios-tweak`.
   Публичный репозиторий = безлимитные минуты сборки, приватный = 2000 минут/мес
   (одна сборка занимает ~4 минуты, так что хватает с запасом).

Альтернатива через терминал (git уже установлен):

```powershell
cd "C:\Users\angelss\Documents\Default Project\ios-tweak\project"
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/ТВОЙ_ЛОГИН/ios-tweak.git
git push -u origin main
```

---

## 3. Сборка `.deb`

1. Открой репозиторий на github.com → вкладка **Actions**.
2. Слева выбери **Build tweak** → кнопка **Run workflow** → **Run workflow**.
3. Через ~4–5 минут открой завершившийся запуск.
4. Внизу, в разделе **Artifacts**, скачай **MyTweak-deb** (это zip).
5. Распакуй — внутри файл вида `com.angelss.mytweak_0.0.1_iphoneos-arm64.deb`.

Сборка также запускается автоматически при каждом `push` в `main`.

---

## 4. Установка на iPhone

1. Перекинь `.deb` на телефон любым способом: iCloud Drive, Telegram («Избранное»),
   почта или кабелем через приложение-файловый менеджер.
2. На телефоне открой `.deb`:
   - **Filza** (поставь из Sileo) → тап по файлу → **Install**;
   - либо поделись файлом → **Open in Sileo**.
3. Дождись установки и сделай **Respring** (Sileo предложит «Restart SpringBoard»).
4. Через ~3 секунды должен появиться алерт **«Твик загружен ✅»**.

Куда ставится твик (rootless):

```
/var/jb/Library/TweakInject/MyTweak.dylib
/var/jb/Library/TweakInject/MyTweak.plist
```

Проверить через SSH/NewTerm:

```sh
ls -l /var/jb/Library/TweakInject/
dpkg -l | grep mytweak
```

---

## 5. Как писать код

`Tweak.x` использует Logos — надстройку над Objective-C:

```objc
%hook ИмяКласса
- (void)метод {
    %orig;              // вызвать оригинальную реализацию
    // ... твой код ...
}
%end
```

Полезное:

- `%hookf(...)` — хук C-функций;
- `%new` — добавить новый метод;
- `%c(Класс)` — превратить имя класса в `Class`;
- `%group` / `%init` — несколько групп хуков.

Цикл работы: правишь `Tweak.x` → commit + push → Actions собирает новый `.deb`
→ ставишь поверх старого (версию в `control` лучше поднимать).

Локальная копия Theos и SDK лежит в `../toolchain` — нужна только для чтения
заголовков и проверки API. Собирать на Windows нельзя (Theos не поддерживает
Windows напрямую), для этого и используется GitHub Actions.

---

## 6. Если что-то пошло не так

| Симптом | Что делать |
|---|---|
| Actions упал на `Install Theos` | Перезапусти workflow: GitHub иногда не может достучаться до github.com |
| `Unable to locate SDK` | Проверь шаг `Add iOS 15.6 SDK` в логе |
| Sileo пишет `Depends: firmware (>= 15.0)` | Телефон не на iOS 15 или джейлбрейк не rootless |
| `.deb` ставится, но твика нет | Не установлен **ElleKit** (`dpkg -l \| grep ellekit`), либо процесс не перезапущен |
| SpringBoard уходит в цикл перезагрузок | Загрузись в safe mode / без твиков, удали пакет: `dpkg -r com.angelss.mytweak` |
| Алерт не появился | Смотри `/var/jb/Library/TweakInject/MyTweak.plist` — там указан `Filter` (SpringBoard) |

Логи твика (через NewTerm или SSH):

```sh
log stream --predicate 'process == "SpringBoard"' --level debug
```

---

## 7. Настройки пакета

- Bundle ID: `com.angelss.mytweak`
- Версия: `0.0.1`
- Архитектура: `iphoneos-arm64` (rootless)
- Минимальная iOS: 15.0
- Цель сборки: SDK 15.6, deployment target 15.0, arm64
