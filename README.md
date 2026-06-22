# CursorLight

一个基于 **ESP32-C3 SuperMini + BLE 蓝牙** 的桌面状态灯项目，用红绿灯挂件直观显示 Cursor Agent / AI 编程过程中的状态，例如思考中、执行中、成功、失败、等待用户操作等。

---

## 1. 项目简介

CursorLight 将一个普通的红绿灯挂件改造成可由电脑控制的桌面状态灯。

核心思路：

- 使用 **ESP32-C3 SuperMini** 作为主控。
- 复用红绿灯挂件内部原有三色灯板。
- 通过 **BLE 蓝牙** 接收电脑端脚本发送的状态指令。
- 结合 Cursor Hooks，让 Cursor Agent 的工作状态自动映射到灯效。

本项目不依赖 Wi-Fi，电脑可以继续连接 5GHz 网络。ESP32-C3 只负责 BLE 通信和灯效控制。

---

## 2. 效果预览

典型状态映射：

| 场景 | 模式 | 灯效 |
|---|---|---|
| 开机展示 | `demo` | 自动展示多种灯效 |
| AI 正在分析 | `thinking` | 连贯跑马灯 |
| AI 正在生成 | `ai` | 柔和慢速跑马灯 |
| 正在执行命令 | `busy` | 黄灯慢闪 |
| 任务成功 | `success` | 绿灯常亮 |
| 任务失败 | `error` | 红灯快闪 |
| 严重异常 / 阻塞 | `alarm` | 红黄交替警灯 |
| 展示模式 | `traffic` | 模拟红绿灯 |
| 关闭 | `off` | 全灭 |

---

## 3. 硬件清单

| 类别 | 物料 | 数量 | 说明 |
|---|---|---:|---|
| 主体 | 红绿灯挂件 / 玩具交通信号灯模型 | 1 个 | 淘宝 / 1688 搜“红绿灯挂件”“交通信号灯挂件” |
| 主控 | ESP32-C3 SuperMini 开发板 | 1 块 | 建议购买已焊针版本，USB-C 更方便 |
| 限流 | 220Ω 1/4w 电阻 | 3 只 | 建议买 10 只装备用 |
| 连线 | 细导线 / 飞线 | 若干 | 推荐 30AWG 硅胶线或漆包线 |
| 供电 | USB-C 数据线 | 1 条 | 必须支持数据传输 |
| 绝缘 | 热缩管 / 绝缘胶带 | 少量 | 用于保护焊点 |
| 工具 | 电烙铁、焊锡丝、镊子、剪线钳 | 若干 | 需要基础焊接工具 |
| 检测 | 万用表 | 可选 | 推荐用于确认焊点和短路 |

说明：

- 本方案复用原玩具灯板，不需要额外购买红、黄、绿三颗 LED。
- 改装后建议使用 USB 供电，不建议继续使用纽扣电池。
- 每路灯建议串联 220Ω 电阻，用于保护 ESP32-C3 和原灯板。

---

## 4. 硬件接线

本项目当前适配的是 **公共正极灯板**。

实测灯位：

| 灯位 | 实际颜色 | ESP32 引脚 |
|---|---|---|
| L1 | 绿灯 | IO2 |
| L2 | 黄灯 | IO3 |
| L3 | 红灯 | IO4 |

接线方式：

```text
ESP32 3.3V  -> 原灯板 + / 原电池正极
ESP32 IO2   -> 220Ω -> L1 控制点 = 绿灯
ESP32 IO3   -> 220Ω -> L2 控制点 = 黄灯
ESP32 IO4   -> 220Ω -> L3 控制点 = 红灯

原灯板 - / 原电池负极：第一版先不要接
```

公共正极逻辑：

```text
GPIO LOW  = 灯亮
GPIO HIGH = 灯灭
```

固件中已经处理了反相输出，正常使用时不需要手动关心高低电平。

注意事项：

- 只焊接在露出的金属焊盘、元件焊脚或电阻焊点上。
- 不要焊在绿色阻焊层表面。
- 焊接完成后，先用万用表检查是否短路，再接入电脑 USB 供电。
- 如果用于成品交付，建议用热熔胶或 UV 胶固定飞线，避免拉断焊点。

---

## 5. 固件说明

固件文件：

```text
ESP32_C3_ToyBoard_CommonAnode_BLE_Enhanced_CursorLight.ino
```

固件特性：

- BLE 广播名：`CursorLight-XXXX`（XXXX 为设备 MAC 地址后 4 位，每台 ESP32 自动生成唯一名称）
- 通信方式：BLE GATT 写入字符串
- 默认开机模式：`green`
- 支持多种状态灯效
- 绿灯 / success 模式 10 分钟后自动熄灭，其他模式不自动超时

BLE 参数：

```text
Device Name: CursorLight-XXXX（自动从 MAC 生成，如 CursorLight-A3F2）
Service UUID: b8b7e001-7a6b-4f4f-9a8b-11c0ffee0001
Mode Characteristic UUID: b8b7e002-7a6b-4f4f-9a8b-11c0ffee0001
```

---

## 6. 烧录固件

### 6.1 安装 Arduino IDE

前往 Arduino 官方页面下载 Arduino IDE 2.x：

```text
https://www.arduino.cc/en/software
```

macOS：

1. 下载 macOS 版本。
2. 打开 `.dmg`。
3. 将 Arduino IDE 拖入 Applications。
4. 首次打开如有安全提示，按系统提示允许。

Windows：

1. 下载 Windows 安装包。
2. 按安装向导完成安装。
3. 如果系统提示安装驱动或允许网络访问，按需允许。

---

### 6.2 安装 ESP32 开发板包

打开 Arduino IDE 后：

1. 进入左侧 **Boards Manager**。
2. 搜索 `esp32`。
3. 安装 **esp32 by Espressif Systems**。
4. 安装完成后重启 Arduino IDE。

注意：不要把 **Arduino ESP32 Boards by Arduino** 作为本项目的主要板包。

---

### 6.3 选择开发板和端口

连接 ESP32-C3 SuperMini 后，在 Arduino IDE 中选择：

```text
Board: ESP32C3 Dev Module
Port: 选择带 USB 标识的串口
```

常见端口：

| 系统 | 端口示例 |
|---|---|
| macOS | `/dev/cu.usbmodemxxxx Serial Port (USB)` |
| Windows | `COM3` / `COM5` 等 |

推荐设置：

| 设置项 | 建议值 |
|---|---|
| USB CDC On Boot | Enabled |
| Upload Speed | 921600 或默认值 |
| Flash Size | 4MB 或默认值 |

如果串口监视器没有输出，优先确认 `USB CDC On Boot` 是否已设为 `Enabled`，然后重新上传固件。

---

### 6.4 上传固件

1. 用 Arduino IDE 打开 `.ino` 文件。
2. 确认 Board 和 Port。
3. 点击左上角 **Upload** 按钮。
4. 上传成功时，Output 区域通常会看到：

```text
Writing at ... 100%
Hash of data verified.
Hard resetting via RTS pin...
```

如果出现 `Connecting...` 后失败，可尝试：

```text
按住 BOOT -> 点击 Upload -> 开始 Writing 后松开 BOOT
```

---

### 6.5 串口检查

打开 Serial Monitor，波特率选择：

```text
115200
```

按一下开发板 `RST`，正常会看到类似日志：

```text
Power on. Default mode: green
Common anode BLE enhanced version.
BLE device name: CursorLight-A3F2
MAC address: 34:85:18:XX:A3:F2
>>> Please configure device_config.json on your computer with this name <<<
BLE advertising started.
Supported modes:
demo / thinking / ai / busy / success / error / alarm / traffic / off / idle / red / yellow / green
```

记下 `BLE device name` 行的完整名称（如 `CursorLight-A3F2`），后面配置电脑端脚本时需要用到。

---

## 7. BLE 控制脚本

电脑端通过 Python 脚本控制灯效：

```text
cursor_light_ble_enhanced.py
```

### 7.1 安装依赖

macOS：

```bash
python3 -m pip install bleak
```

Windows：

```powershell
py -3 -m pip install bleak
```

macOS 如果提示 `Bluetooth device is turned off`，但系统蓝牙已经打开，请到：

```text
系统设置 -> 隐私与安全性 -> 蓝牙
```

给 Terminal、iTerm、Cursor 或当前终端应用授权。

---

### 7.2 手动测试

macOS：

```bash
python3 cursor_light_ble_enhanced.py demo
python3 cursor_light_ble_enhanced.py thinking
python3 cursor_light_ble_enhanced.py ai
python3 cursor_light_ble_enhanced.py busy
python3 cursor_light_ble_enhanced.py success
python3 cursor_light_ble_enhanced.py error
python3 cursor_light_ble_enhanced.py alarm
python3 cursor_light_ble_enhanced.py traffic
python3 cursor_light_ble_enhanced.py off
```

Windows：

```powershell
py -3 cursor_light_ble_enhanced.py demo
py -3 cursor_light_ble_enhanced.py thinking
py -3 cursor_light_ble_enhanced.py ai
py -3 cursor_light_ble_enhanced.py busy
py -3 cursor_light_ble_enhanced.py success
py -3 cursor_light_ble_enhanced.py error
py -3 cursor_light_ble_enhanced.py alarm
py -3 cursor_light_ble_enhanced.py traffic
py -3 cursor_light_ble_enhanced.py off
```

---

### 7.3 多设备配置

如果同一空间内有多台 CursorLight（例如两位同事各一台），需要为每台电脑指定要控制的 ESP32 设备，避免互相串扰。

1. 烧录固件后，打开串口监视器记下你的 ESP32 设备名，如 `CursorLight-A3F2`。

2. 在脚本所在目录（`cursor-light-bundle/` 或 `.cursor/hooks/cursor-light/`）创建 `device_config.json`：

```json
{
  "target_device_name": "CursorLight-A3F2"
}
```

3. 把 `CursorLight-A3F2` 换成你自己设备串口输出的名字。

如果没有 `device_config.json`，脚本会用默认名 `CursorLight` 扫描，可能连到附近其他同名设备。单台设备使用时无需配置。

---

## 8. 固件模式

| mode | 灯效说明 | 典型用途 |
|---|---|---|
| `demo` | 默认开机展示，循环展示多种灯效 | 演示、待机展示 |
| `thinking` | 连贯跑马灯：L1 绿 -> L2 黄 -> L3 红 | AI 分析、规划中 |
| `ai` | 柔和慢速跑马灯 | AI 生成内容、长任务处理中 |
| `busy` | 黄灯慢闪 | 构建、测试、安装依赖 |
| `success` | 绿灯常亮 | 任务成功 |
| `error` | 红灯快闪 | 普通失败或报错 |
| `alarm` | 红黄交替警灯，带短渐变 | 严重异常或阻塞 |
| `traffic` | 红灯闪变绿，绿灯闪变黄，循环 | 展示或自动过渡 |
| `off` | 全部关闭 | 关闭灯效 |
| `red` | 红灯常亮 | 单灯测试 |
| `yellow` | 黄灯常亮 | 等待人工处理 / 单灯测试 |
| `green` | 绿灯常亮 | 空闲 / 单灯测试 |

---

## 9. 自动超时规则

固件内置自动超时，避免状态灯长时间保持高亮。

| 当前模式 | 自动行为 |
|---|---|
| `green` / `success` | 10 分钟后自动 `off` |
| 其他模式 | 不自动超时 |
| `off` / `idle` | 不自动切换 |

---

## 10. Cursor Hooks 集成

CursorLight 可以通过用户目录下的 `.cursor/hooks` 与 Cursor Agent 联动。

推荐安装目录：

| 平台 | 目录 |
|---|---|
| macOS | `~/.cursor/hooks/cursor-light/` |
| Windows | `%USERPROFILE%\.cursor\hooks\cursor-light\` |

典型文件结构：

```text
cursor-light/
├─ install-cursor-light.sh
├─ hooks.json.snippet
├─ agent-light.sh
├─ ble_gate.py
├─ cursor_light_ble_enhanced.py
├─ hook-*.sh
└─ README.md
```

说明：

- `cursor_light_ble_enhanced.py`：向 ESP32-C3 BLE GATT 特征写入 mode。
- `ble_gate.py`：防抖、并发去重，避免多个 Hook 同时触发导致灯效乱跳。
- `agent-light.sh`：统一处理 Agent 状态判断与模式切换。
- `hook-*.sh`：各类 Cursor Hook 事件入口。
- `hooks.json.snippet`：Cursor Hooks 配置片段。

---

## 11. macOS 安装 Cursor Hooks

```bash
mkdir -p ~/.cursor/hooks/cursor-light
cd ~/.cursor/hooks/cursor-light
unzip ~/Downloads/cursor-light-bundle.zip
chmod +x *.sh
```

安装依赖：

```bash
python3 -m pip install --user bleak
```

配置 Hooks：

```bash
mkdir -p ~/.cursor
cp hooks.json.snippet ~/.cursor/hooks.json
```

如果已经存在 `~/.cursor/hooks.json`，请手动合并，不要直接覆盖。

自检：

```bash
cd ~/.cursor/hooks/cursor-light
python3 cursor_light_ble_enhanced.py green
python3 cursor_light_ble_enhanced.py thinking
python3 cursor_light_ble_enhanced.py busy
python3 cursor_light_ble_enhanced.py alarm
python3 cursor_light_ble_enhanced.py success
```

---

## 12. Windows 安装 Cursor Hooks

如果当前发布包只有 `.sh` Hook 入口，Windows 需要通过 Git Bash 执行，或后续提供 `.ps1` 版本入口。

PowerShell 示例：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.cursor\hooks\cursor-light"
Expand-Archive "$env:USERPROFILE\Downloads\cursor-light-bundle.zip" "$env:USERPROFILE\.cursor\hooks\cursor-light" -Force
Set-Location "$env:USERPROFILE\.cursor\hooks\cursor-light"
```

安装依赖：

```powershell
py --version
py -m pip install --user bleak
```

配置 Hooks：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.cursor"
Copy-Item ".\hooks.json.snippet" "$env:USERPROFILE\.cursor\hooks.json"
```

如果已经存在 `hooks.json`，请手动合并。

自检：

```powershell
py .\cursor_light_ble_enhanced.py green
py .\cursor_light_ble_enhanced.py thinking
py .\cursor_light_ble_enhanced.py busy
py .\cursor_light_ble_enhanced.py alarm
py .\cursor_light_ble_enhanced.py success
```

---

## 13. 推荐状态映射

| Cursor / 开发场景 | 推荐 mode |
|---|---|
| Agent 开始分析需求 | `thinking` |
| Agent 正在生成或修改代码 | `ai` |
| 执行终端命令 / 构建 / 测试 | `busy` |
| 命令成功 / 构建通过 / 测试通过 | `success` |
| 普通失败 / 报错 | `error` |
| 严重阻塞 / 需要立即处理 | `alarm` |
| 等待用户确认 | `yellow` |
| 关闭灯效 | `off` |

常见流程：

```text
普通任务：thinking -> busy -> success / error
等待确认：thinking -> yellow
严重异常：busy -> alarm
```

---

## 14. 日志与调试

macOS：

```bash
tail -f ~/.cursor/hooks/cursor-light/ble.log
```

Windows PowerShell：

```powershell
Get-Content "$env:USERPROFILE\.cursor\hooks\cursor-light\ble.log" -Wait
```

常见现象：

| 现象 | 优先检查 |
|---|---|
| 找不到设备 | ESP32-C3 是否供电、BLE 广播名是否为 CursorLight、距离是否过远、系统蓝牙是否开启 |
| 写入失败 | GATT UUID 是否一致 |
| 灯效频繁跳变 | `ble_gate.py` 是否存在，Hook 是否重复注册 |
| Cursor 没有触发 | `hooks.json` 是否加载，路径是否正确，是否重启 Cursor |
| 一直停在 busy / thinking | 可能是状态没有正确收口，检查 `ble_gate.py` 和 `state.json` |
| 灯色不对应 | 确认 IO2=L1 绿，IO3=L2 黄，IO4=L3 红 |

---

## 15. 常见问题

### Arduino IDE 搜不到 ESP32C3 Dev Module

确认已安装：

```text
esp32 by Espressif Systems
```

安装后重启 Arduino IDE，并在：

```text
Tools -> Board -> esp32
```

中查找 `ESP32C3 Dev Module`。

### 看不到串口端口

优先检查：

- USB 线是否支持数据传输。
- 是否换过 USB 口。
- Windows 是否能在设备管理器中看到 COM 口。

### 上传失败

尝试：

```text
按住 BOOT -> 点击 Upload -> 开始 Writing 后松开 BOOT
```

同时关闭 Serial Monitor，避免串口被占用。

### 串口无输出

确认：

```text
USB CDC On Boot = Enabled
```

然后重新上传固件，并打开 115200 波特率串口监视器。

### 找不到 BLE 设备

检查：

- ESP32-C3 是否已通电。
- 固件是否已成功运行。
- 串口监视器输出的 `BLE device name` 是什么（如 `CursorLight-A3F2`）。
- 如果配了 `device_config.json`，确认 `target_device_name` 和串口输出的名字一致。
- 电脑蓝牙是否打开。
- macOS 是否给 Terminal / Cursor 蓝牙权限。

### 同事的指令控制了我的灯

多台 CursorLight 在同一空间时需要各自配置：

1. 每台 ESP32 串口输出的设备名不同（MAC 后缀不同）。
2. 每台电脑的脚本目录放一份 `device_config.json`，填入自己设备的名字。
3. 详细步骤见 7.3 节。

### macOS 提示 Bluetooth device is turned off

即使系统蓝牙已打开，也可能是终端没有蓝牙权限。请到：

```text
系统设置 -> 隐私与安全性 -> 蓝牙
```

授权当前终端应用，然后重启终端。

### python 命令不存在

macOS 默认通常使用：

```bash
python3
```

Windows 推荐使用：

```powershell
py -3
```

---

## 16. 卸载

macOS：

```bash
rm -rf ~/.cursor/hooks/cursor-light
nano ~/.cursor/hooks.json
```

Windows PowerShell：

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.cursor\hooks\cursor-light"
notepad "$env:USERPROFILE\.cursor\hooks.json"
```

删除 `hooks.json` 中 cursor-light 相关配置后，重启 Cursor。

---

## 17. 参考链接

- Arduino IDE 下载页：`https://www.arduino.cc/en/software`
- Arduino IDE 安装说明：`https://support.arduino.cc/hc/en-us/articles/360019833020-Download-and-install-Arduino-IDE`
- Arduino-ESP32 安装文档：`https://docs.espressif.com/projects/arduino-esp32/en/latest/installing.html`
