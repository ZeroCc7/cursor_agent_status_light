# CodeFree-O Agent Light 快速开始

## 5 分钟安装

### 1. 安装依赖

```bash
pip install bleak
```

### 2. 部署插件

```bash
copy opencode-agent-light.js C:\Users\<用户名>\.codefree-o\plugins\
```

如脚本不在 `__dirname/cursor-light-bundle` 下，编辑插件第 9 行 `BUNDLE_DIR` 指向实际路径。

### 3. 烧录 ESP32

Arduino IDE → 打开 `.ino` → 选 `ESP32C3 Dev Module` → Upload

### 4. 查看设备名

串口监视器（115200）找到：

```text
BLE device name: CursorLight-XXXX
```

### 5. 配置目标设备（多设备必选）

在脚本目录创建 `device_config.json`：

```json
{
  "target_device_name": "CursorLight-XXXX"
}
```

单台设备可跳过此步。

### 6. 重启 CodeFree-O

插件自动加载。

## 灯效说明

| LED | 含义 |
|-----|------|
| 黄灯呼吸 | AI 思考中（thinking） |
| 黄灯快闪 | 工具执行中（busy，2s 防抖） |
| 绿灯常亮 | 空闲（green，保持 3s） |
| 红灯快闪 | 出错（error） |
| 红黄交替 | 等待授权（alarm） |

## 手动测试

```bash
python cursor_light_ble_enhanced.py thinking
python cursor_light_ble_enhanced.py busy
python cursor_light_ble_enhanced.py green
python cursor_light_ble_enhanced.py error
python cursor_light_ble_enhanced.py alarm
python cursor_light_ble_enhanced.py off
```

## 故障排查

- **灯不亮** → 检查供电和接线，看串口监视器
- **找不到设备** → `device_config.json` 里的名字要和串口输出一致
- **串到别人的灯** → 各自配置 `device_config.json`
- **插件无反应** → 看 `opencode-light.log`，确认路径正确

详细文档见 [README.md](./README.md)
