import path from "path";
import { fileURLToPath } from "url";
import { execFile } from "child_process";
import { promisify } from "util";

const execFileAsync = promisify(execFile);
const __dirname = path.dirname(fileURLToPath(import.meta.url));

const BUNDLE_DIR = path.join(__dirname, "cursor-light-bundle");
const PYTHON = process.env.OPENCODE_LIGHT_PYTHON || "python";
const GATE_SCRIPT = path.join(BUNDLE_DIR, "ble_gate_win.py");
const BLE_SCRIPT = path.join(BUNDLE_DIR, "cursor_light_ble_enhanced.py");
const LOG_FILE = path.join(BUNDLE_DIR, "opencode-light.log");
const BUSY_DELAY_MS = 2000;
const GREEN_HOLD_MS = 3000;

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
      log(`gate skip ${result} (want ${mode})`);
      return;
    }
    const actualMode = result.slice(4);
    log(`gate ok -> ble ${actualMode}`);
    await bleWrite(actualMode);
  } catch (e) {
    log(`gate error: ${e.message}`);
  }
}

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
    const item = bleQueue.shift();
    try {
      await execFileAsync(PYTHON, [BLE_SCRIPT, item.mode], {
        timeout: 30000,
        windowsHide: true,
      });
      log(`ble sent ${item.mode}`);
    } catch (e) {
      log(`ble error: ${e.message}`);
    }
    item.resolve();
  }

  bleBusy = false;
}

export function createAgentLightPlugin() {
  let phase = "idle";
  let busyTimer = null;
  let greenUntil = 0;

  function clearBusyTimer() {
    if (busyTimer) {
      clearTimeout(busyTimer);
      busyTimer = null;
    }
  }

  async function toThinking(gateAction = "thinking") {
    clearBusyTimer();
    if (phase === "thinking") return;
    if (Date.now() < greenUntil) {
      log(`thinking suppressed (green hold ${Math.round((greenUntil - Date.now()) / 1000)}s)`);
      return;
    }
    phase = "thinking";
    await gateSend(gateAction, "thinking");
  }

  async function toBusy() {
    if (phase === "busy") return;
    clearBusyTimer();
    busyTimer = setTimeout(async () => {
      busyTimer = null;
      phase = "busy";
      await gateSend("busy", "busy");
    }, BUSY_DELAY_MS);
  }

  async function toGreen() {
    clearBusyTimer();
    phase = "idle";
    greenUntil = Date.now() + GREEN_HOLD_MS;
    log("-> green");
    await gateSend("stop-success", "green");
  }

  async function toError() {
    clearBusyTimer();
    phase = "idle";
    greenUntil = 0;
    await gateSend("stop-error", "error");
  }

  async function toAlarm() {
    clearBusyTimer();
    phase = "idle";
    greenUntil = 0;
    await gateSend("await-user", "alarm");
  }

  return async ({ project, client, $, directory, worktree }) => {
    log("AgentLightPlugin v8.0 ready");

    return {
      event: async ({ event }) => {
        const type = event.type;
        const props = event.properties || {};

        if (type === "chat.request.received") {
          greenUntil = 0;
          await toThinking("turn-start");
          return;
        }

        if (type === "chat.request.preprocess.done") {
          await toThinking();
          return;
        }

        if (type === "message.updated") {
          const role = props.info?.role;
          if (role === "user") {
            await toThinking("turn-start");
          } else if (role === "assistant") {
            await toThinking();
          }
          return;
        }

        if (type === "message.part.updated") {
          const partType = props.part?.type;
          if (partType === "tool") {
            log(`tool part: ${props.part?.tool || "unknown"}`);
            await toBusy();
          } else {
            await toThinking();
          }
          return;
        }

        if (type === "message.part.delta") {
          await toThinking();
          return;
        }

        if (type === "session.status") {
          const statusType = props.status?.type;
          if (statusType === "idle" || statusType === "cancelled" || statusType === "aborted" || statusType === "stopped") {
            log(`session.status: ${statusType} -> green`);
            await toGreen();
          } else if (statusType === "error") {
            log("session.status: error");
            await toError();
          } else if (statusType === "busy") {
            await toBusy();
          } else {
            log(`session.status: ${statusType} (unhandled)`);
          }
          return;
        }

        if (type === "session.idle") {
          await toGreen();
          return;
        }

        if (type === "session.error") {
          log("session.error -> error");
          await toError();
          return;
        }

        if (type === "permission.asked") {
          await toAlarm();
          return;
        }
      },

      "tool.execute.before": async () => {
        await toBusy();
      },

      "tool.execute.after": async (input, output) => {
        clearBusyTimer();
        if (output?.error != null) {
          await toError();
        } else {
          phase = "thinking";
        }
      },
    };
  };
}

export const AgentLightPlugin = createAgentLightPlugin();
