const { app, BrowserWindow, Menu, shell } = require("electron");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const http = require("node:http");
const net = require("node:net");
const path = require("node:path");

let serverProcess;
let mainWindow;

function parseEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const env = {};
  const lines = fs.readFileSync(filePath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const equalsIndex = trimmed.indexOf("=");
    if (equalsIndex <= 0) continue;
    const key = trimmed.slice(0, equalsIndex).trim();
    let value = trimmed.slice(equalsIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    env[key] = value;
  }
  return env;
}

function resolveAdminDir() {
  if (app.isPackaged) return path.join(process.resourcesPath, "app");
  return path.resolve(__dirname, "..");
}

function loadRuntimeEnv(adminDir) {
  const candidates = [
    path.join(adminDir, ".env"),
    path.join(process.cwd(), ".env"),
    path.join(process.cwd(), ".env.local"),
    path.join(app.getPath("userData"), "admin.env"),
  ];
  return candidates.reduce(
    (merged, candidate) => ({ ...merged, ...parseEnvFile(candidate) }),
    {},
  );
}

function getFreePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close(() => resolve(address.port));
    });
  });
}

function waitForServer(url, timeoutMs = 45000) {
  const startedAt = Date.now();
  return new Promise((resolve, reject) => {
    const check = () => {
      const request = http.get(url, (response) => {
        response.resume();
        resolve();
      });
      request.on("error", () => {
        if (Date.now() - startedAt > timeoutMs) {
          reject(new Error("Admin server ishga tushmadi."));
          return;
        }
        setTimeout(check, 350);
      });
      request.setTimeout(2500, () => {
        request.destroy();
      });
    };
    check();
  });
}

function renderErrorWindow(message) {
  const safeMessage = String(message).replace(/[&<>"']/g, (char) => {
    return {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    }[char];
  });
  mainWindow.loadURL(
    `data:text/html;charset=utf-8,${encodeURIComponent(`
      <html>
        <body style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;margin:48px;color:#111827;background:#f8fafc">
          <h1>LabProof Admin ishga tushmadi</h1>
          <p style="font-size:16px;line-height:1.5;color:#475569">${safeMessage}</p>
          <p style="color:#64748b">.env sozlamalari va internet aloqasini tekshiring.</p>
        </body>
      </html>
    `)}`,
  );
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1440,
    height: 940,
    minWidth: 1100,
    minHeight: 760,
    title: "LabProof Admin",
    backgroundColor: "#f7f7ff",
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  mainWindow.once("ready-to-show", () => mainWindow.show());
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("http://127.0.0.1")) return { action: "allow" };
    shell.openExternal(url);
    return { action: "deny" };
  });

  Menu.setApplicationMenu(
    Menu.buildFromTemplate([
      {
        label: "LabProof Admin",
        submenu: [
          { role: "about" },
          { type: "separator" },
          { role: "hide" },
          { role: "hideOthers" },
          { role: "unhide" },
          { type: "separator" },
          { role: "quit" },
        ],
      },
      {
        label: "Ko'rinish",
        submenu: [
          { role: "reload", label: "Yangilash" },
          { role: "forceReload", label: "Majburiy yangilash" },
          { role: "togglefullscreen", label: "To'liq ekran" },
        ],
      },
    ]),
  );
}

async function startAdminServer() {
  const adminDir = resolveAdminDir();
  const serverPath = path.join(adminDir, "server.js");
  if (!fs.existsSync(serverPath)) {
    throw new Error(`${serverPath} topilmadi. Avval npm run desktop:build ishlating.`);
  }

  const runtimeEnv = loadRuntimeEnv(adminDir);
  const port = await getFreePort();
  const url = `http://127.0.0.1:${port}`;
  const nodePath = app.isPackaged
    ? path.join(process.resourcesPath, "app", "node_modules")
    : path.join(adminDir, "node_modules");
  const env = {
    ...process.env,
    ...runtimeEnv,
    NODE_ENV: "production",
    HOSTNAME: "127.0.0.1",
    PORT: String(port),
    NEXT_PUBLIC_APP_URL: url,
    NODE_PATH: nodePath,
    ELECTRON_RUN_AS_NODE: "1",
  };
  const bootstrap = [
    "const Module = require('node:module');",
    `process.env.NODE_PATH = ${JSON.stringify(nodePath)};`,
    "Module._initPaths();",
    `require(${JSON.stringify(serverPath)});`,
  ].join("\n");

  serverProcess = spawn(process.execPath, ["-e", bootstrap], {
    cwd: adminDir,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });

  serverProcess.stdout.on("data", (chunk) => {
    console.log(`[admin] ${chunk.toString().trim()}`);
  });
  serverProcess.stderr.on("data", (chunk) => {
    console.error(`[admin] ${chunk.toString().trim()}`);
  });
  serverProcess.once("exit", (code) => {
    if (code && mainWindow && !mainWindow.isDestroyed()) {
      renderErrorWindow(`Admin server to'xtadi. Kod: ${code}`);
    }
  });

  await waitForServer(url);
  return url;
}

app.whenReady().then(async () => {
  createWindow();
  mainWindow.loadURL(
    `data:text/html;charset=utf-8,${encodeURIComponent(`
      <html>
        <body style="margin:0;height:100vh;display:grid;place-items:center;background:linear-gradient(135deg,#f8f7ff,#eef4ff);font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;color:#111827">
          <main style="text-align:center">
            <div style="width:72px;height:72px;border-radius:24px;margin:0 auto 18px;background:#6d4aff;box-shadow:0 18px 40px rgba(109,74,255,.25)"></div>
            <h1 style="margin:0 0 8px;font-size:28px">LabProof Admin</h1>
            <p style="margin:0;color:#64748b;font-size:16px">Admin panel ishga tushmoqda...</p>
          </main>
        </body>
      </html>
    `)}`,
  );

  try {
    const url = await startAdminServer();
    await mainWindow.loadURL(url);
  } catch (error) {
    renderErrorWindow(error?.message || error);
  }
});

app.on("before-quit", () => {
  if (serverProcess && !serverProcess.killed) {
    serverProcess.kill();
  }
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
