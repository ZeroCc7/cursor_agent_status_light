import path from "path";
import { execFile } from "child_process";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

const BUNDLE_DIR = path.resolve(
  "E:\\WorkSpace\\Zerocc\\study\\cursor_agent_status_light\\cursor-light-bundle"
);
const PYTHON = process.env.OPENCODE_LIGHT_PYTHON || "python";
const GATE_SCRIPT = path.join(BUNDLE_DIR, "ble_gate_win.py");
const BLE_SCRIPT = path.join(BUNDLE_DIR, "cursor_light_ble_enhanced.py");
const LOG_FILE = path.join(BUNDLE_DIR, "opencode-light.log");
const BUSY_DELAY_MS = 2000;

function log(msg) {
  const ts = new Date().toISOString().replace("T", " ").slice(0, 19);
  try {
    const fs = require("fs");
    fs.appendFileSync(LOG_FILE, `[${ts}] ${msg}\n`);
  } catch {}
}

async function gateSend(gateAction, mode) {
  try {
    const { stdout } = await execFileAsync(PYTHON, [GATE_SCRIPT, gateAction, mode], {
      timeout: 5000,
      windowsHide: true,
    });
    const result = stdout.trim();
    if (!result.startsWith("yes:")) {
      log(`skip ${result} (want ${mode})`);
      return;
    }
    const actualMode = result.slice(4);
    log(`send mode=${actualMode}`);
    await bleWrite(actualMode);
  } catch (e) {
    log(`gate error: ${e.message}`);
  }
}

// ---- BLE mutex: 同一时刻只允许一个 BLE 写入进程 ----
let bleBusy = false;
const bleQueue = [];

function bleWrite(mode) {
  return new Promise((resolve) => {
    bleQueue.push({ mode, resolve });
    drainBleQueue();
  });
}

async function drainBleQueue() {
  if (bleBusy) return;
  if (bleQueue.length === 0) return;

  bleBusy = true;

  while (bleQueue.length > 0) {
    // 只取最后一个，丢弃中间排队的（只关心最新状态）
    const item = bleQueue.pop();
    const skipped = bleQueue.length;
    bleQueue.length = 0;
    if (skipped > 0) {
      log(`ble queue: skipped ${skipped} stale write(s)`);
    }

    try {
      await execFileAsync(PYTHON, [BLE_SCRIPT, item.mode], {
        timeout: 15000,
        windowsHide: true,
      });
    } catch (e) {
      log(`ble error: ${e.message}`);
    }
    item.resolve();
  }

  bleBusy = false;
}

export function createAgentLightPlugin({
  gateSendFn = gateSend,
  logFn = log,
} = {}) {
  let currentPhase = "";
  let busyTimer = null;

  function clearBusyTimer() {
    if (busyTimer) {
      clearTimeout(busyTimer);
      busyTimer = null;
    }
  }

  async function markThinking(action = "thinking") {
    clearBusyTimer();
    if (currentPhase === "thinking") return;
    currentPhase = "thinking";
    await gateSendFn(action, "thinking");
  }

  async function markBusy() {
    if (currentPhase === "busy") return;
    clearBusyTimer();
    // 延迟 2 秒再切 busy：短于 2 秒的工具调用不切灯，避免快速抖动
    busyTimer = setTimeout(async () => {
      busyTimer = null;
      currentPhase = "busy";
      await gateSendFn("busy", "busy");
    }, BUSY_DELAY_MS);
  }

  async function markIdle() {
    clearBusyTimer();
    currentPhase = "";
    logFn("session idle -> green");
    await gateSendFn("stop-success", "green");
  }

  async function markError() {
    clearBusyTimer();
    currentPhase = "";
    await gateSendFn("stop-error", "error");
  }

  return async ({ project, client, $, directory, worktree }) => {
    logFn("AgentLightPlugin v7.3 ready");

  return {
    event: async ({ event }) => {
      const type = event.type;
      const props = event.properties || {};

      if (type === "chat.request.received") {
        await markThinking("turn-start");
        return;
      }

      if (type === "message.updated") {
        const role = props.info?.role;
        if (role === "user") {
          await markThinking("turn-start");
        } else if (role === "assistant") {
          await markThinking();
        }
        return;
      }

      if (type === "message.part.updated") {
        const partType = props.part?.type;
        if (partType === "tool") {
          const toolName = props.part?.tool || "unknown";
          logFn(`tool part: ${toolName}`);
          await markBusy();
        } else {
          await markThinking();
        }
        return;
      }

      if (
        type === "message.part.delta" ||
        type === "session.next.text.started" ||
        type === "session.next.text.delta" ||
        type === "session.next.text.ended" ||
        type === "session.next.reasoning.started" ||
        type === "session.next.reasoning.delta" ||
        type === "session.next.reasoning.ended"
      ) {
        await markThinking();
        return;
      }

      if (type === "session.next.tool.called" || type === "session.next.tool.progress") {
        await markBusy();
        return;
      }

      // 单个工具完成：不闪绿灯，取消待定的 busy 定时器
      if (type === "session.next.tool.success") {
        clearBusyTimer();
        currentPhase = "thinking";
        return;
      }

      if (type === "session.next.tool.failed") {
        await markError();
        return;
      }

      if (type === "session.status") {
        const statusType = props.status?.type;
        if (statusType === "idle") {
          await markIdle();
        } else if (statusType === "error") {
          logFn("session.status: error");
          await markError();
        }
        return;
      }

      if (type === "session.idle") {
        await markIdle();
        return;
      }

      if (type === "permission.asked") {
        clearBusyTimer();
        currentPhase = "";
        await gateSendFn("await-user", "alarm");
        return;
      }
    },

    "tool.execute.before": async (input) => {
      await markBusy();
    },

    "tool.execute.after": async (input, output) => {
      clearBusyTimer();
      const hasError = output?.error != null;
      if (hasError) {
        await markError();
      } else {
        // 工具完成，代理可能继续 → thinking，不发 success
        currentPhase = "thinking";
      }
    },
  };
};
}

export const AgentLightPlugin = createAgentLightPlugin();
