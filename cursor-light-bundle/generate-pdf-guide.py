#!/usr/bin/env python3
"""生成《Cursor CursorLight 联动迁移手册》PDF"""
from pathlib import Path

from fpdf import FPDF

OUT = Path.home() / "Desktop" / "Cursor-CursorLight-联动迁移手册.pdf"

# macOS 常见中文字体
FONT_CANDIDATES = [
    Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf"),
    Path("/Library/Fonts/Arial Unicode.ttf"),
    Path("/System/Library/Fonts/STHeiti Light.ttc"),
    Path("/System/Library/Fonts/PingFang.ttc"),
]


def find_font() -> Path:
    for p in FONT_CANDIDATES:
        if p.exists():
            return p
    raise SystemExit("未找到中文字体，请安装 Arial Unicode 或 PingFang 后重试")


class GuidePDF(FPDF):
    def footer(self):
        self.set_y(-15)
        self.set_font("zh", size=9)
        self.set_text_color(120, 120, 120)
        self.cell(0, 10, f"第 {self.page_no()} 页", align="C")


def main():
    font_path = find_font()
    pdf = GuidePDF()
    pdf.set_auto_page_break(auto=True, margin=18)

    # TTC 在部分 fpdf 版本不可用，优先 ttf
    if font_path.suffix.lower() == ".ttc":
        font_path = Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf")
    pdf.add_font("zh", "", str(font_path))
    pdf.set_font("zh", size=11)

    def h1(t):
        pdf.ln(4)
        pdf.set_font("zh", size=16)
        pdf.set_text_color(20, 60, 120)
        pdf.multi_cell(0, 10, t)
        pdf.set_text_color(0, 0, 0)
        pdf.set_font("zh", size=11)
        pdf.ln(2)

    def h2(t):
        pdf.ln(2)
        pdf.set_font("zh", size=13)
        pdf.set_text_color(40, 40, 40)
        pdf.multi_cell(0, 8, t)
        pdf.set_font("zh", size=11)
        pdf.set_text_color(0, 0, 0)
        pdf.ln(1)

    def p(t):
        pdf.multi_cell(0, 6.5, t)
        pdf.ln(1)

    def bullet(items):
        for it in items:
            pdf.multi_cell(0, 6.5, f"  • {it}")
        pdf.ln(2)

    pdf.add_page()
    pdf.set_font("zh", size=20)
    pdf.set_text_color(20, 60, 120)
    pdf.multi_cell(0, 12, "Cursor × CursorLight\nBLE 红绿灯联动")
    pdf.ln(2)
    pdf.set_font("zh", size=12)
    pdf.set_text_color(80, 80, 80)
    pdf.multi_cell(0, 8, "迁移到其它 Mac 安装手册（用户级 ~/.cursor，不进项目仓库）")
    pdf.set_text_color(0, 0, 0)
    pdf.ln(6)

    h1("一、你需要准备什么")
    bullet(
        [
            "ESP32-C3 板子，已烧录 BLE 固件，蓝牙广播名：CursorLight",
            "新 Mac：macOS，已安装 Cursor IDE",
            "Python 3（系统自带即可）",
            "本机已配对/授权蓝牙（终端或 Cursor 需有蓝牙权限）",
            "从旧电脑拷贝的 cursor-light 文件夹（见下文打包方式）",
        ]
    )

    h1("二、灯效含义（Agent 状态）")
    bullet(
        [
            "green — 空闲 / 会话结束",
            "thinking — 你刚发送 Prompt，Agent 尚未调工具",
            "busy — Agent 正在执行工具",
            "alarm — 需要你操作：Plan 等 Build、AskQuestion 问卷",
            "success — 本轮 Agent 正常结束",
            "error — 失败或中止",
        ]
    )
    p("说明：终端命令、MCP 默认不亮 alarm（避免无弹窗也闪灯）。")

    h1("三、文件应放在哪里")
    p("全部在用户目录，与具体项目无关：")
    bullet(
        [
            "~/.cursor/hooks.json — Hook 注册表",
            "~/.cursor/hooks/cursor-light/ — 脚本目录",
            "  agent-light.sh — 核心逻辑",
            "  ble_gate.py — 防抖与并行去重",
            "  cursor_light_ble_enhanced.py — BLE 发 mode",
            "  hook-*.sh — 各事件入口",
            "  ble.log — 运行日志（自动生成）",
            "  state.json — 状态（自动生成）",
        ]
    )

    h1("四、从旧电脑打包")
    bullet(
        [
            "在旧 Mac 上打开终端，执行：",
            "  cd ~/.cursor/hooks/cursor-light",
            "  zip -r ~/Desktop/cursor-light-bundle.zip . \\",
            "    -x 'ble.log' -x 'state.json' -x 'state.lock'",
            "将 cursor-light-bundle.zip 和本 PDF 拷到新 Mac（U 盘 / 网盘 / AirDrop）",
            "可选：同时拷贝 ~/.cursor/hooks.json（若新电脑尚无 hooks）",
        ]
    )

    h1("五、在新 Mac 上安装")
    h2("5.1 解压")
    bullet(
        [
            "mkdir -p ~/.cursor/hooks/cursor-light",
            "cd ~/.cursor/hooks/cursor-light",
            "unzip ~/Desktop/cursor-light-bundle.zip",
            "chmod +x *.sh",
        ]
    )
    h2("5.2 一键安装（推荐）")
    bullet(
        [
            "cd ~/.cursor/hooks/cursor-light",
            "bash install-cursor-light.sh",
            "脚本会：复制文件、pip install bleak、试发 green、提示合并 hooks.json",
        ]
    )
    h2("5.3 配置 hooks.json")
    p(
        "若新电脑没有 ~/.cursor/hooks.json："
        "将 hooks.json.snippet 复制为 ~/.cursor/hooks.json。"
    )
    p(
        "若已有 hooks.json：用编辑器把 snippet 里的 hooks 段合并进去，"
        "不要重复注册同名事件；路径保持 ./hooks/cursor-light/..."
    )
    h2("5.4 Python 依赖")
    bullet(
        [
            "python3 -m pip install --user bleak",
            "自定义 Python：export CURSOR_LIGHT_PYTHON=/path/to/python3",
        ]
    )
    h2("5.5 蓝牙权限")
    bullet(
        [
            "系统设置 → 隐私与安全性 → 蓝牙 → 允许 Terminal / Cursor",
            "首次连接建议在终端手动测试（见下节）",
        ]
    )

    pdf.add_page()
    h1("六、安装后自检")
    bullet(
        [
            "cd ~/.cursor/hooks/cursor-light",
            "python3 cursor_light_ble_enhanced.py green   # 应亮绿灯",
            "python3 cursor_light_ble_enhanced.py alarm  # 应亮 alarm",
            "python3 cursor_light_ble_enhanced.py success",
        ]
    )
    p("若提示「没有找到 CursorLight」：确认 ESP32 通电、距离、固件、Mac 蓝牙已开。")

    h1("七、启用 Cursor Hooks")
    bullet(
        [
            "完全退出 Cursor（Cmd+Q），再重新打开",
            "Settings → Hooks，确认列表中有 cursor-light 相关命令",
            "发一条 Agent 任务，观察灯：thinking → busy → success/error",
            "Plan 模式写完计划、出现 Build 按钮时应为 alarm，点 Build 执行完后 success",
        ]
    )
    p("调试：tail -f ~/.cursor/hooks/cursor-light/ble.log")

    h1("八、硬件固件（仅新做板子时）")
    bullet(
        [
            "设备名：CursorLight",
            "GATT 特征 UUID：b8b7e002-7a6b-4f4f-9a8b-11c0ffee0001",
            "写入 UTF-8 字符串 mode（如 busy、success、alarm）",
            "固件与 Arduino/ESP-IDF 工程请保留你原有的烧录文档；",
            "本联动只要求 BLE 名称与 UUID 与上一致。",
        ]
    )

    h1("九、常见问题")
    h2("灯一直 busy / Thinking 闪")
    p("多为并行 Hook；确认 ble_gate.py 存在且为最新版。重启 Cursor。")
    h2("Plan 结束应是 alarm 却 success")
    p("看 ble.log 是否出现 plan write -> awaiting Build；升级 agent-light.sh 后重启 Cursor。")
    h2("执行完应是 success 却 alarm")
    p("确认 build_started 仅在写入非 .plan.md 文件后触发；升级脚本。")
    h2("换电脑后完全无灯")
    p("先单独跑 python3 cursor_light_ble_enhanced.py green，再查 Hooks 是否加载。")

    h1("十、卸载")
    bullet(
        [
            "删除 ~/.cursor/hooks/cursor-light 目录",
            "编辑 ~/.cursor/hooks.json 去掉 cursor-light 相关项",
            "重启 Cursor",
        ]
    )

    pdf.ln(4)
    p(f"文档生成路径：{OUT}")
    p("bundle 目录默认：~/.cursor/hooks/cursor-light/")

    pdf.output(str(OUT))
    print(f"已生成：{OUT}")


if __name__ == "__main__":
    main()
