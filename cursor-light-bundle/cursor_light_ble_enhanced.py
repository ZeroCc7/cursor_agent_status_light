#!/usr/bin/env python3
import asyncio
import json
import subprocess
import sys
from pathlib import Path

try:
    from bleak import BleakScanner, BleakClient
except ImportError:
    subprocess.check_call(
        [sys.executable, "-m", "pip", "install", "bleak", "--quiet"]
    )
    from bleak import BleakScanner, BleakClient

DEVICE_NAME_DEFAULT = "CursorLight"
MODE_CHAR_UUID = "b8b7e002-7a6b-4f4f-9a8b-11c0ffee0001"
CACHE_PATH = Path(__file__).resolve().parent / "ble_device_cache.json"
CONFIG_PATH = Path(__file__).resolve().parent / "device_config.json"

VALID_MODES = {
    "red", "yellow", "green", "busy", "error", "thinking",
    "ai", "success", "traffic", "alarm", "demo", "off", "idle",
}


def load_device_config():
    """读取 device_config.json，获取本机目标设备名。
    返回 None 表示未配置，将使用默认名扫描。"""
    try:
        data = json.loads(CONFIG_PATH.read_text())
        name = data.get("target_device_name", "").strip()
        if name:
            return name
    except FileNotFoundError:
        pass
    except Exception as e:
        print(f"读取 device_config.json 出错: {e}")
    return None


def get_target_device_name():
    """获取要扫描的 BLE 设备名。
    优先用 device_config.json 中配置的精确名，否则用默认前缀。"""
    configured = load_device_config()
    if configured:
        return configured
    return DEVICE_NAME_DEFAULT


def load_cached_address():
    try:
        data = json.loads(CACHE_PATH.read_text())
        addr = data.get("address", "")
        ts = data.get("ts", 0)
        if addr and (asyncio.get_event_loop().time() or 1) and ts > 0:
            return addr
    except Exception:
        pass
    return None


def save_cached_address(address):
    try:
        CACHE_PATH.write_text(json.dumps({"address": address, "ts": 1}))
    except Exception:
        pass


async def find_device():
    target_name = get_target_device_name()
    configured = load_device_config() is not None

    cached = load_cached_address()
    if cached:
        print(f"使用缓存地址: {cached}")
        try:
            async with BleakClient(cached, timeout=5.0) as client:
                if client.is_connected:
                    return cached
        except Exception:
            print("缓存地址连接失败，清除缓存并重新扫描...")
            try:
                CACHE_PATH.unlink()
            except Exception:
                pass

    print(f"正在扫描 BLE 设备：{target_name} ...")
    device = await BleakScanner.find_device_by_name(target_name, timeout=5.0)
    if device is None:
        if not configured:
            print(f"提示：未配置 device_config.json，正在用默认名 '{DEVICE_NAME_DEFAULT}' 扫描。")
            print(f"如果有多台设备，请创建 {CONFIG_PATH}")
            print(f'  内容：{{"target_device_name": "CursorLight-XXXX"}}')
            print(f"  其中 XXXX 是你的 ESP32 串口监视器显示的设备名后缀。")
        return None
    save_cached_address(device.address)
    print(f"找到设备: {device.name} ({device.address})")
    return device.address


async def main():
    if len(sys.argv) < 2:
        print("用法: python3 cursor_light_ble_enhanced.py <mode>")
        print("可用 mode:", ", ".join(sorted(VALID_MODES)))
        sys.exit(1)

    mode = sys.argv[1].strip().lower()
    if mode not in VALID_MODES:
        print(f"未知 mode: {mode}")
        print("可用 mode:", ", ".join(sorted(VALID_MODES)))
        sys.exit(1)

    address = await find_device()
    if address is None:
        target_name = get_target_device_name()
        print(f"没有找到 {target_name}。请确认设备已通电且距离足够近")
        sys.exit(2)

    async with BleakClient(address) as client:
        if not client.is_connected:
            print("连接失败")
            sys.exit(3)

        target_char = None
        for service in client.services:
            for char in service.characteristics:
                if 'write' in char.properties and 'b8b7e002' in str(char.uuid):
                    target_char = char.uuid
                    break
            if target_char:
                break

        if not target_char:
            print("未找到目标特征")
            sys.exit(4)

        print(f"已连接，发送 mode={mode}")
        await client.write_gatt_char(target_char, mode.encode("utf-8"), response=True)
        print("发送完成")


if __name__ == "__main__":
    asyncio.run(main())
