#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Проверка .deb для FluidX перед установкой на iPhone.

Использование:
    python tools/inspect_deb.py путь\\к\\com.dolboebvaibcode.fluidx_0.1.0_iphoneos-arm64.deb

Скрипт не требует ничего, кроме Python 3.8+ (на этой машине уже стоит).
"""

import io
import os
import plistlib
import struct
import sys
import tarfile

# Чтобы русский текст нормально печатался в PowerShell/CMD на Windows
if os.name == "nt":
    try:
        import ctypes
        ctypes.windll.kernel32.SetConsoleOutputCP(65001)
    except Exception:  # noqa: BLE001
        pass
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:  # noqa: BLE001
        pass

EXPECTED_PACKAGE = "com.dolboebvaibcode.fluidx"
EXPECTED_ARCH = "iphoneos-arm64"

# Куда rootless-пакеты кладут твик. Theos по умолчанию использует путь
# MobileSubstrate (его читает ElleKit на Dopamine), libhooker — TweakInject.
DYLIB_DIRS = [
    "var/jb/Library/MobileSubstrate/DynamicLibraries",
    "var/jb/usr/lib/TweakInject",
]

CPU_NAMES = {
    0x0100000C: "arm64",
    0x0100000C | 0x02000000: "arm64e",
    0x0000000C: "arm",
    0x01000007: "x86_64",
}
FILETYPE_NAMES = {6: "MH_DYLIB", 2: "MH_EXECUTE", 8: "MH_BUNDLE"}


def parse_ar(blob):
    """Разбирает формат ar (внутри .deb)."""
    if not blob.startswith(b"!<arch>\n"):
        raise ValueError("это не ar-архив — файл не похож на .deb")
    offset = 8
    while offset + 60 <= len(blob):
        header = blob[offset:offset + 60]
        name = header[0:16].decode("ascii", "replace").strip()
        try:
            size = int(header[48:58].decode("ascii").strip())
        except ValueError:
            break
        start = offset + 60
        yield name.rstrip("/"), blob[start:start + size]
        offset = start + size + (size % 2)


def extract_tar(blob):
    """Возвращает {путь: содержимое} для сжатого/несжатого tar."""
    files = {}
    with tarfile.open(fileobj=io.BytesIO(blob), mode="r:*") as tf:
        for member in tf:
            if member.isfile():
                data = tf.extractfile(member)
                if data is not None:
                    name = member.name.lstrip("./")
                    files[name] = data.read()
    return files


def parse_control(text):
    fields = {}
    for line in text.splitlines():
        if ":" in line and not line.startswith(" "):
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip()
    return fields


def _thin_header(blob, start):
    """Разбирает тонкий (thin) Mach-O по смещению start."""
    if start + 28 > len(blob):
        return None

    magic_le = struct.unpack_from("<I", blob, start)[0]
    magic_be = struct.unpack_from(">I", blob, start)[0]

    if magic_le in (0xFEEDFACF, 0xFEEDFACE):
        endian, is64 = "<", magic_le == 0xFEEDFACF
    elif magic_be in (0xFEEDFACF, 0xFEEDFACE):
        endian, is64 = ">", magic_be == 0xFEEDFACF
    else:
        return None

    cputype, cpusubtype, filetype = struct.unpack_from(endian + "III", blob, start + 4)
    name = CPU_NAMES.get(cputype)
    if name is None:
        name = hex(cputype)
    # cpusubtype 2 (младший байт) = ABI arm64e
    if name == "arm64" and (cpusubtype & 0xFF) == 2:
        name = "arm64e"

    return {
        "arch": name,
        "cputype": cputype,
        "cpusubtype": cpusubtype,
        "filetype": FILETYPE_NAMES.get(filetype, str(filetype)),
        "is64": is64,
    }


def macho_info(blob):
    """Читает заголовок Mach-O (thin или fat/universal)."""
    if len(blob) < 8:
        return None

    magic_be = struct.unpack_from(">I", blob, 0)[0]
    if magic_be in (0xCAFEBABE, 0xCAFEBABF):
        fat64 = magic_be == 0xCAFEBABF
        count = struct.unpack_from(">I", blob, 4)[0]
        entry_size = 32 if fat64 else 20
        if count == 0 or count > 16:
            return None

        infos = []
        for index in range(count):
            base = 8 + index * entry_size
            if base + entry_size > len(blob):
                break
            if fat64:
                _ct, _cs, offset, _size, _align, _res = struct.unpack_from(">IIQQII", blob, base)
            else:
                _ct, _cs, offset, _size, _align = struct.unpack_from(">IIIII", blob, base)
            info = _thin_header(blob, offset)
            if info is not None:
                infos.append(info)

        if not infos:
            return None

        preferred = next((i for i in infos if i["arch"] in ("arm64", "arm64e")), infos[0])
        preferred["archs"] = [i["arch"] for i in infos]
        preferred["fat"] = True
        return preferred

    info = _thin_header(blob, 0)
    if info is not None:
        info["archs"] = [info["arch"]]
        info["fat"] = False
    return info


def main():
    if len(sys.argv) != 2:
        print("Использование: python tools/inspect_deb.py <файл.deb>")
        return 2

    path = sys.argv[1]
    if not os.path.isfile(path):
        print("[!!] Файл не найден: %s" % path)
        return 2

    print("Проверяю: %s (%.1f КБ)\n" % (os.path.basename(path), os.path.getsize(path) / 1024))

    with open(path, "rb") as fh:
        blob = fh.read()

    members = dict(parse_ar(blob))
    control_blob = next((v for k, v in members.items() if k.startswith("control.tar")), None)
    data_blob = next((v for k, v in members.items() if k.startswith("data.tar")), None)

    if control_blob is None or data_blob is None:
        print("[!!] Внутри нет control.tar или data.tar — архив битый")
        return 1

    control = parse_control(extract_tar(control_blob).get("control", b"").decode("utf-8", "replace"))
    files = extract_tar(data_blob)

    problems = []

    def check(ok, message):
        print(("[OK] " if ok else "[!!] ") + message)
        if not ok:
            problems.append(message)

    print("--- Пакет ---")
    package = control.get("Package", "?")
    check(package == EXPECTED_PACKAGE, "Package: %s" % package)
    check(control.get("Architecture") == EXPECTED_ARCH, "Architecture: %s" % control.get("Architecture", "?"))
    print("      Name: %s" % control.get("Name", "?"))
    print("      Version: %s" % control.get("Version", "?"))
    print("      Depends: %s" % control.get("Depends", "-"))

    print("\n--- Файлы ---")
    print("      всего файлов: %d" % len(files))
    for name in sorted(files):
        print("      " + name)

    print("\n--- Обязательные пути (rootless) ---")
    dylib_dir = next((d for d in DYLIB_DIRS if (d + "/FluidX.dylib") in files), None)
    if dylib_dir is None:
        check(False, "не найден FluidX.dylib ни в одном из путей: %s" % ", ".join(DYLIB_DIRS))
    else:
        print("      каталог твика: /%s" % dylib_dir)

    dylib_path = dylib_dir + "/FluidX.dylib" if dylib_dir else None
    plist_path = dylib_dir + "/FluidX.plist" if dylib_dir else None

    check(dylib_path is not None and dylib_path in files, "есть %s" % (dylib_path or "FluidX.dylib"))
    check(plist_path is not None and plist_path in files, "есть %s" % (plist_path or "FluidX.plist"))

    rootless_ok = all(name.startswith("var/jb/") for name in files if name.startswith(("Library/", "var/", "usr/")))
    check(rootless_ok, "все файлы лежат в /var/jb (схема rootless)")

    if dylib_path and dylib_path in files:
        print("\n--- Бинарник ---")
        info = macho_info(files[dylib_path])
        if info is None:
            check(False, "FluidX.dylib — не Mach-O файл")
        else:
            archs = ", ".join(info.get("archs") or [info["arch"]])
            check(info["arch"] in ("arm64", "arm64e"), "архитектура: %s (срезы: %s)" % (info["arch"], archs))
            check(info["filetype"] == "MH_DYLIB", "тип: %s" % info["filetype"])
            print("      cpusubtype: 0x%08x" % info["cpusubtype"])

    if plist_path and plist_path in files:
        print("\n--- Фильтр загрузки ---")
        try:
            plist = plistlib.loads(files[plist_path])
            bundles = plist.get("Filter", {}).get("Bundles", [])
            check("com.apple.springboard" in bundles, "Filter Bundles: %s" % (bundles or "пусто"))
        except Exception as exc:  # noqa: BLE001
            check(False, "не удалось прочитать %s: %s" % (plist_path, exc))

    print()
    if problems:
        print("ИТОГ: %d проблем(ы). Такой .deb ставить не стоит." % len(problems))
        return 1

    print("ИТОГ: всё в порядке, можно ставить на iPhone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
