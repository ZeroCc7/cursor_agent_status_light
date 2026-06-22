# CodeFree-O Agent Light Plugin

## 简介

CodeFree-O 全局插件（v8.0），将 AI 编程助手的实时状态映射到 ESP32-C3 BLE 状态灯，一眼看到 AI 在干什么。

```
opencode-agent-light.js (插件, 状态机 + BLE 队列)
        ↓
ble_gate_win.py (防抖网关, state.json 文件锁)
        ↓
cursor_light_ble_enhanced.py (BLE 写入, bleak 库)
        ↓
ESP32-C3 BLE 状态灯 (CursorLight-XXXX)
```

## 灯效状态

| 灯效 | 含义 | ESP32 模式 |
|------|------|-----------|
| 黄灯呼吸 | AI 思考 / 生成中 | `thinking` |
| 黄灯快闪（500ms） | 工具执行中 | `busy` |
| 绿灯常亮 | 空闲 / 任务完成 | `green` |
| 红灯快闪 | 出错 | `error` |
| 红黄交替 | 等待用户授权 | `alarm` |

## 事件映射

| 事件 | 灯状态 | 说明 |
|------|--------|------|
| `chat.request.received` | thinking | 用户发送消息，清除 green hold |
| `chat.request.preprocess.done` | thinking | 请求预处理完成 |
| `message.updated` (role=user) | thinking | 用户消息更新 |
| `message.updated` (role=assistant) | thinking | AI 回复中 |
| `message.part.updated` (part=tool) | busy | 工具开始执行 |
| `message.part.updated` (其他) | thinking | AI 输出文本 |
| `message.part.delta` | thinking | 流式输出 |
| `session.status` (idle/cancelled/aborted/stopped) | green | 空闲 |
| `session.status` (error) | error | 会话错误 |
| `session.status` (busy) | busy | 会话繁忙 |
| `session.idle` | green | 空闲（主要收口事件） |
| `session.error` | error | 会话异常（手动停止也会触发） |
| `permission.asked` | alarm | 等待用户授权 |
| `tool.execute.before` | busy | 工具执行前 |
| `tool.execute.after` (无错) | thinking | 工具成功，继续等待 |
| `tool.execute.after` (有错) | error | 工具失败 |

未处理的事件（与灯无关，自动忽略）：`message.removed`、`session.updated`、`session.diff`、`session.compacted`、`file.watcher.updated`、`file.edited`、`codefree.metric.*`

## 状态机

```
用户发消息 → thinking(黄灯呼吸)
                ↓
         工具执行 → busy(黄灯快闪, 2s 防抖)
                ↓
         工具成功 → thinking(继续等)
                ↓
         session.idle → green(绿灯, 保持 3s)

异常：
  工具失败 → error(红灯快闪)
  手动停止 → error → session.idle → green
  需要授权 → alarm(红黄交替)
```

防抖机制（两层）：

- 插件层：busy 延迟 2s 触发，避免短命令频繁闪灯；green 完成后保持 3s，期间新的 thinking 被压制
- 网关层：`ble_gate_win.py` 对每种模式设独立防抖窗口（thinking 5s / busy 8s / alarm 500ms / success 3s / error 3s / green 3s），用 `state.json` + 文件锁保证原子性

## 安装

### 1. 安装 Python 依赖

```bash
pip install bleak
```

### 2. 部署插件文件

将以下文件复制到 CodeFree-O 插件目录：

```bash
copy opencode-agent-light.js C:\Users\<用户名>\.codefree-o\plugins\
```

插件通过 `BUNDLE_DIR`（第 9 行）定位 Python 脚本目录，默认指向 `__dirname/cursor-light-bundle`。如果脚本放在其他位置，修改这一行。

### 3. 烧录 ESP32 固件

用 Arduino IDE 打开 `ESP32_C3_ToyBoard_CommonAnode_BLE_Enhanced_CursorLight.ino`，选择 `ESP32C3 Dev Module`，上传固件。

### 4. 记下设备名

烧录完成后，打开串口监视器（115200），找到这行：

```text
BLE device name: CursorLight-XXXX
```

记下完整名称（如 `CursorLight-068E`）。

### 5. 配置目标设备（多设备必选）

在 Python 脚本所在目录创建 `device_config.json`：

```json
{
  "target_device_name": "CursorLight-068E"
}
```

把 `CursorLight-068E` 换成你自己设备的名字。单台设备使用时可以跳过这步，脚本会用默认名 `CursorLight` 扫描。

### 6. 重启 CodeFree-O

插件自动加载，日志写入 `opencode-light.log`。

## 手动测试

通过网关脚本测试各模式：

```bash
python ble_gate_win.py turn-start thinking
python ble_gate_win.py busy busy
python ble_gate_win.py idle green
python ble_gate_win.py stop-error error
python ble_gate_win.py await-user alarm
```

也可以直接调用 BLE 脚本（跳过防抖）：

```bash
python cursor_light_ble_enhanced.py thinking
python cursor_light_ble_enhanced.py busy
python cursor_light_ble_enhanced.py green
python cursor_light_ble_enhanced.py error
python cursor_light_ble_enhanced.py alarm
python cursor_light_ble_enhanced.py off
```

## 多设备配置

同一办公室有多台 CursorLight 时，每台电脑各自配置 `device_config.json`，指向自己的 ESP32。

每台 ESP32 因为 MAC 地址不同，烧同一份固件会自动生成不同的设备名。各自电脑填自己的名字就不会串。

详细步骤见上面第 4、5 步。

## 文件清单

| 文件 | 说明 |
|------|------|
| `opencode-agent-light.js` | v8.0 插件入口，状态机 + BLE 队列 |
| `ble_gate_win.py` | 防抖网关，Windows 版（msvcrt 文件锁） |
| `cursor_light_ble_enhanced.py` | BLE 写入脚本（bleak），支持 device_config.json |
| `device_config.json` | 本机目标 ESP32 设备名配置 |
| `opencode-light.log` | 运行日志（自动生成） |
| `state.json` | 网关防抖状态（自动生成） |

## 日志查看

```bash
# 实时查看
type opencode-light.log

# PowerShell
Get-Content opencode-light.log -Wait
```

## 故障排查

| 现象 | 检查 |
|------|------|
| 灯不亮 | ESP32 供电、接线、串口监视器是否有输出 |
| 找不到设备 | 串口输出的设备名和 `device_config.json` 是否一致 |
| 同事的灯被我的控制了 | 各自 `device_config.json` 是否填了自己设备的名字 |
| 插件不工作 | 查看 `opencode-light.log`，确认 BUNDLE_DIR 路径正确 |
| BLE 写入偶发失败 | 正常现象，下次写入通常自动恢复 |
| 手动停止先红后绿 | 正常：`session.error` → 红灯，随后 `session.idle` → 绿灯 |
