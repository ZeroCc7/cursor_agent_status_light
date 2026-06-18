# CodeFree-O Agent Light 集成指南

本项目将 CodeFree-O 的 AI 状态映射到 ESP32-C3 BLE 红绿灯设备，实现实时状态可视化。

## 功能特性

- **实时状态同步**：根据 CodeFree-O 的不同操作状态自动切换 LED 灯效
- **低延迟响应**：通过 BLE（蓝牙低功耗）实现毫秒级状态切换
- **智能防抖**：避免短时间内重复发送指令，减少蓝牙连接次数
- **空闲检测**：3 秒无操作自动切换到绿色常亮（空闲状态）
- **成功反馈**：工具执行成功后会短暂显示绿色（500ms）再转回黄色
- **错误提示**：执行失败时显示红色快闪

## 系统架构

```
CodeFree-O 插件 (opencode-agent-light.js)
    ↓
Python 防抖脚本 (ble_gate_win.py)
    ↓
BLE 发送脚本 (cursor_light_ble_enhanced.py)
    ↓
ESP32-C3 设备 (CursorLight)
```

## 安装部署

### 1. 硬件准备

- ESP32-C3 开发板（或支持 BLE 的其他开发板）
- LED 红绿灯（共阳极或共阴极）
- 按照硬件接线图连接 ESP32-C3 和 LED

### 2. 固件烧录

1. 打开 Arduino IDE
2. 安装 ESP32 开发板支持包
3. 打开 `ESP32_C3_ToyBoard_CommonAnode_BLE_Enhanced_CursorLight.ino` 文件
4. 选择开发板：ESP32C3 Dev Module
5. 配置 WiFi 信息（可选，用于 OTA 升级）
6. 点击上传按钮烧录固件

### 3. 软件依赖

安装 Python 和必需的库：

```bash
pip install bleak
```

### 4. 插件安装

复制插件文件到 CodeFree-O 插件目录：

**Windows:**
```bash
copy opencode-agent-light.js C:\Users\<用户名>\.codefree-o\plugins\
```

修改插件文件中的插件目录路径：
```javascript
const BUNDLE_DIR = path.resolve(
  "<你的项目路径>\\codefree-o"
);
```

或者设置环境变量：
```bash
set OPENCODE_LIGHT_BUNDLE_DIR=<你的项目路径>\\codefree-o
```

### 5. 设备连接

1. 为 ESP32-C3 供电
2. 打开手机蓝牙，搜索设备名为 "CursorLight"
3. 连接成功后 LED 会显示绿色常亮

### 6. 软件配置

编辑 `ble_gate_win.py`，确认 BLE 设备名称：
```python
 DEVICE_NAME = "CursorLight"
```

编辑 `cursor_light_ble_enhanced.py`，确认服务 UUID：
```python
 SERVICE_UUID = "b8b7e001-7a6b-4f4f-9a8b-11c0ffee0001"
 MODE_CHAR_UUID = "b8b7e002-7a6b-4f4f-9a8b-11c0ffee0001"
```

## 使用方式

### 自动模式（推荐）

CodeFree-O 启动时会自动加载插件，插件会监听以下事件并自动切换 LED 状态：

| 状态 | 触发条件 | 灯效 |
|------|---------|------|
| thinking | 用户发送消息 / AI 正在生成回复 | 黄灯慢闪烁 |
| busy | AI 正在执行工具（如运行代码） | 黄灯较快闪烁 |
| success | 工具执行成功完成 | 绿灯常亮（500ms） |
| green | 空闲状态（3秒无操作） | 绿灯常亮 |
| error | 执行失败 | 红灯快闪 |
| alarm | 等待用户授权 | 红黄交替闪烁 |

### 手动模式

可以直接通过命令行控制 LED 状态：

```bash
# 切换到 thinking 模式
python ble_gate_win.py turn-start thinking

# 切换到 busy 模式
python ble_gate_win.py busy busy

# 切换到 green 模式
python ble_gate_win.py idle green

# 切换到 error 模式
python ble_gate_win.py stop-error error

# 切换到 demo 演示模式
python ble_gate_win.py demo demo
```

### 查看 BLE 日志

BLE 脚本会输出详细日志到控制台：

```bash
python cursor_light_ble_enhanced.py green
```

日志会显示设备连接状态、写入结果等。

## 工作原理

### 插件事件监听

插件通过 CodeFree-O 的插件系统监听以下事件：

1. **chat.request.received**: 用户发送新消息
2. **message.updated**: 消息更新（AI 回复）
3. **message.part.updated**: 消息部分更新（工具执行）
4. **tool.execute.before**: 工具执行前
5. **tool.execute.after**: 工具执行后
6. **session.idle**: 会话空闲
7. **session.status**: 会话状态变化
8. **permission.asked**: 需要用户授权

### 防抖机制

`ble_gate_win.py` 实现了防抖逻辑，避免短时间内重复发送相同指令：

- 使用文件锁确保同一时间只有一个进程运行
- 记录上一次的指令和发送时间
- 如果短时间内收到相同指令，则跳过发送

### 状态转换规则

```
初始状态 → green (空闲)

用户发消息 → thinking
  ├─ 工具执行前 → busy
  ├─ 工具执行成功 → success (500ms) → thinking
  ├─ 工具执行失败 → error
  ├─ 等待授权 → alarm
  └─ 3秒无活动 → green (空闲)

空闲状态 → 用户发消息 → thinking
```

## 故障排查

### LED 不亮

1. 检查 ESP32-C3 是否正常供电
2. 检查 LED 接线是否正确
3. 查看 LED 序列监视器是否有错误信息
4. 确认 BLE 设备是否正常连接

### BLE 连接失败

1. 确认 ESP32-C3 的蓝牙是否开启
2. 检查设备名称是否为 "CursorLight"
3. 重启 ESP32-C3 设备
4. 检查手机蓝牙是否开启

### Python 脚本报错

1. 确认已安装 `bleak` 库：`pip install bleak`
2. 检查 Python 版本（建议 3.7+）
3. 查看日志文件 `opencode-light.log`

### 插件不工作

1. 确认插件文件在正确的目录
2. 检查 `opencode-light.log` 日志文件
3. 重启 CodeFree-O
4. 确认 `BUNDLE_DIR` 路径配置正确

## 进阶配置

### 调整 LED 亮度

编辑 ESP32 固件中的亮度参数：

```cpp
// LED 最大亮度 (0-255)
#define RED_MAX 70
#define YELLOW_MAX 60
#define GREEN_MAX 60
```

### 调整灯光节奏

编辑 `fadeInOut()` 函数中的时间参数：

```cpp
void fadeInOut(int r, int g, int b, int fadeDuration, int holdDuration, int fadeOutDuration, int offDuration) {
  // fadeDuration: 渐亮时间 (ms)
  // holdDuration: 保持时间 (ms)
  // fadeOutDuration: 渐暗时间 (ms)
  // offDuration: 熄灭时间 (ms)
}
```

### 更改空闲检测时间

编辑插件中的空闲检测时间：

```javascript
// 3 秒无操作认为空闲
idleTimer = setTimeout(async () => {
  // ...
}, 3000);
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `opencode-agent-light.js` | CodeFree-O 插件，监听事件并控制 LED |
| `ble_gate_win.py` | Windows 版防抖脚本，避免重复发送指令 |
| `cursor_light_ble_enhanced.py` | BLE 通信脚本，发送控制指令到 ESP32 |
| `ESP32_C3_ToyBoard_CommonAnode_BLE_Enhanced_CursorLight.ino` | ESP32 固件代码 |
| `README.md` | 本文件，使用说明文档 |

## 许可证

本项目基于 MIT 许可证开源。

## 支持

如有问题，请提交 Issue 或联系开发者。
