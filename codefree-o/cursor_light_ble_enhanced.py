#!/usr/bin/env python3
# 控制 ESP32-C3 CursorLight BLE 状态灯
#
# 首次安装：
#   python3 -m pip install bleak
#
# 用法：
#   python3 cursor_light_ble_enhanced.py demo
#   python3 cursor_light_ble_enhanced.py thinking
#   python3 cursor_light_ble_enhanced.py ai
#   python3 cursor_light_ble_enhanced.py busy
#   python3 cursor_light_ble_enhanced.py success
#   python3 cursor_light_ble_enhanced.py error
#   python3 cursor_light_ble_enhanced.py alarm
#   python3 cursor_light_ble_enhanced.py traffic
#   python3 cursor_light_ble_enhanced.py off

import asyncio
import sys
from bleak import BleakScanner, BleakClient

DEVICE_NAME = "CursorLight"
MODE_CHAR_UUID = "b8b7e002-7a6b-4f4f-9a8b-11c0ffee0001"

VALID_MODES = {
    "red",
    "yellow",
    "green",
    "busy",
    "error",
    "thinking",
    "ai",
    "success",
    "traffic",
    "alarm",
    "demo",
    "off",
}

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

    print(f"正在扫描 BLE 设备：{DEVICE_NAME} ...")
    device = await BleakScanner.find_device_by_name(DEVICE_NAME, timeout=10.0)

    if device is None:
        print("没有找到 CursorLight。请确认：")
        print("1. ESP32 已通电")
        print("2. 代码已刷入 BLE 增强版")
        print("3. 距离足够近")
        print("4. macOS 蓝牙已打开，并给 Terminal 蓝牙权限")
        sys.exit(2)

    print(f"找到设备: {device.address}")

    async with BleakClient(device) as client:
        if not client.is_connected:
            print("连接失败")
            sys.exit(3)

        print(f"已连接，发送 mode={mode}")
        await client.write_gatt_char(MODE_CHAR_UUID, mode.encode("utf-8"), response=True)
        print("发送完成")

if __name__ == "__main__":
    asyncio.run(main())
