# CodeFree-O Agent Light 快速开始

## 快速安装（5 分钟）

### 1. 安装 Python 依赖

```bash
pip install bleak
```

### 2. 复制插件到 CodeFree-O

```bash
copy opencode-agent-light.js C:\Users\<用户名>\.codefree-o\plugins\
```

### 3. 修改插件路径

编辑 `C:\Users\<用户名>\.codefree-o\plugins\opencode-agent-light.js`，修改第 7 行：

```javascript
const BUNDLE_DIR = path.resolve(
  "E:\\WorkSpace\\Zerocc\\study\\cursor_agent_status_light\\codefree-o"
);
```

### 4. 烧录 ESP32 固件

1. 打开 Arduino IDE
2. 打开 `ESP32_C3_ToyBoard_CommonAnode_BLE_Enhanced_CursorLight.ino`
3. 选择开发板：ESP32C3 Dev Module
4. 上传固件

### 5. 启动设备并测试

为 ESP32-C3 供电，LED 应显示绿色常亮

重启 CodeFree-O，插件自动加载

## 状态说明

| LED 状态 | 含义 |
|---------|------|
| 🟡 黄灯慢闪 | AI 正在思考（thinking） |
| 🟡 黄灯快闪 | AI 正在执行工具（busy） |
| 🟢 绿灯常亮 | 空闲状态 |
| 🟢 绿灯闪 0.5 秒 | 工具执行成功 |
| 🔴 红灯快闪 | 执行失败 |
| 🔴🟡 红|黄闪 | 等待授权 |

## 手动测试

```bash
# 测试 thinking 模式
python ble_gate_win.py turn-start thinking

# 测试 busy 模式
python ble_gate_win.py busy busy

# 测试 green 模式
python ble_gate_win.py idle green

# 测试 success 反馈
python ble_gate_win.py tool-success success

# 测试 error 模式
python ble_gate_win.py stop-error error

# 演示模式（所有灯效循环）
python ble_gate_win.py demo demo
```

## 查看详细文档

完整的安装和配置说明请参考 [README.md](./README.md)

## 故障排查

### LED 不亮
- 检查供电和接线
- 查看 ESP32 串口监视器

### BLE 连接失败
- 确认设备名为 "CursorLight"
- 重启 ESP32

### 插件不工作
- 检查 `E:\WorkSpace\Zerocc\study\cursor_agent_status_light\codefree-o\opencode-light.log` 日志
- 确认插件路径配置正确
- 重启 CodeFree-O
