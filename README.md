# Browser Control Skill (Chrome & Microsoft Edge)

面向 AI Coding Agent 的可视化浏览器自动化技能规范与辅助脚本库，同时支持 **Google Chrome** 与 **Microsoft Edge**。

通过 Chrome DevTools Protocol (`chrome-devtools-mcp`) 直接接入用户日常正在运行的真实浏览器实例，**保留用户的登录态、Cookie 与书签**，并**不占用物理鼠标**；在本地开发测试场景下也支持无头模式（Headless），并可与桌面控制 MCP（如 [`computer-use-v2`](https://github.com/enenhengrusty/computer-use-v2)）联动完成弹窗自愈、系统文件对话框与无人值守人机验证。

---

## 核心特性

- **双浏览器兼容（Chrome & Edge）**：
  - **Chrome**：支持 `chrome-devtools-mcp --auto-connect` 无感接入。
  - **Microsoft Edge**：附带 [ensure_edge_cdp.ps1](scripts/ensure_edge_cdp.ps1)，自动解决 Edge「启动增强 (Startup Boost)」后台常驻进程导致调试端口被吞的常见问题，并支持 `--browser-url=http://127.0.0.1:9222` 接入。
- **双场景选型**：日常登录态业务接入主浏览器；本地开发/E2E 测试允许使用 Playwright `headless=True`。
- **低 Token 提取规范**：优先使用 `evaluate_script` 直接提取结构化 JSON，避免无障碍树快照撑爆上下文。
- **标签页卫生（借还即焚）**：优先复用已有标签页，临时新建标签页任务完成后自动关闭。
- **SPA 防竞态与自愈**：显式异步等待、Cookie/弹窗清理、PDF 边界逃逸、远程调试授权弹窗自动点击。
- **人机验证双轨机制**：默认友好请求人类协同；无人值守时可联动 `computer-use-v2` 完成 L1 点击与 L2 滑块拟人拖拽。

---

## 环境要求

### 必需依赖
1. **Node.js / `npx`**（用于运行官方 [`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp)）
2. **Google Chrome** 或 **Microsoft Edge**（Chromium 111+；自动连接建议 Chrome 128+）

### 可选依赖（按需）
- **桌面控制联动**：[`computer-use-v2`](https://github.com/enenhengrusty/computer-use-v2)（用于自动点击远程调试授权弹窗、处理“另存为”系统对话框、无人值守滑块拖拽）
- **Python 批处理 / PDF 提取**：`playwright`（用于直连 CDP 或无头测试）、`httpx`、`PyMuPDF`

---

## 快速安装与配置

### 1. 安装 Skill 到 Agent 目录

将本仓库克隆到你的 Agent 技能目录，例如 Antigravity：

```powershell
git clone https://github.com/enenhengrusty/browser-control.git "$env:USERPROFILE\.gemini\config\skills\browser-control"
```

（若使用其他支持 `SKILL.md` 的 Agent，将本仓库放入对应的 `skills/browser-control` 目录即可。）

---

### 2. 配置 MCP 服务

#### 方案 A：使用 Google Chrome（推荐直接 `--auto-connect`）

在 MCP 配置文件（如 `%USERPROFILE%\.gemini\config\mcp_config.json`）中添加（参考 [examples/mcp_config.chrome.json](examples/mcp_config.chrome.json)）：

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--auto-connect",
        "--no-usage-statistics"
      ]
    }
  }
}
```
> Windows 下若 `npx` 无法直接解析，请将 `"command"` 改为 `"npx.cmd"`。

#### 方案 B：使用 Microsoft Edge（通过本地 CDP 端口）

1. 先用本仓库脚本启动带调试端口的 Edge（自动处理 Startup Boost 后台进程并添加 `--remote-allow-origins=*`）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\ensure_edge_cdp.ps1
   ```
   > 若当前已有可见 Edge 窗口不想关闭，可传入临时隔离配置目录：
   > `powershell -ExecutionPolicy Bypass -File .\scripts\ensure_edge_cdp.ps1 -UserDataDir "$env:TEMP\edge-cdp-profile"`

2. 在 MCP 配置文件中添加（参考 [examples/mcp_config.edge.json](examples/mcp_config.edge.json)）：
   ```json
   {
     "mcpServers": {
       "edge-devtools": {
         "command": "npx",
         "args": [
           "-y",
           "chrome-devtools-mcp@latest",
           "--browser-url=http://127.0.0.1:9222",
           "--no-usage-statistics"
         ]
       }
     }
   }
   ```

---

### 3. 测试 Playwright 直连 Edge CDP（可选）

```powershell
pip install playwright
python .\scripts\edge_driver_example.py --port 9222
```

---

## 目录结构

```text
browser-control/
├── SKILL.md                      # Agent 技能主规范（Chrome & Edge 通用）
├── README.md                     # 安装与配置指南
├── LICENSE                       # MIT License
├── scripts/
│   ├── ensure_edge_cdp.ps1       # Edge CDP 安全唤醒脚本（处理 Startup Boost）
│   ├── ensure_chrome_cdp.ps1     # Chrome CDP 安全唤醒脚本
│   └── edge_driver_example.py    # Playwright connect_over_cdp 直连示例
├── examples/
│   ├── mcp_config.chrome.json    # Chrome MCP 配置模板
│   └── mcp_config.edge.json      # Edge MCP 配置模板
└── docs/
    └── EDGE_AUTOMATION_GUIDE.md  # Edge 跨平台自动化与避坑深度指南
```

---

## 延伸阅读

- [Edge 跨平台自动化与避坑深度指南](docs/EDGE_AUTOMATION_GUIDE.md)
- 配套桌面控制插件：[computer-use-v2](https://github.com/enenhengrusty/computer-use-v2)
