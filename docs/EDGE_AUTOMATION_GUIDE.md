# Microsoft Edge 浏览器自动化与 Agent 控制插件开发指南（通用版）

> **适用对象**：AI Coding Agent / 自主智能体（Subagent）  
> **目标系统**：通用操作系统（Windows / macOS / Linux）  
> **设计目标**：向 Agent 传授在任意目标主机上开发浏览器控制插件、配置 MCP 协议服务，并通过 CDP（Chrome DevTools Protocol）直接驱动 Microsoft Edge 的标准化方法。文档不绑定任何特定主机的用户路径。

---

## 目录
1. [浏览器内核与跨平台路径探测机制](#1-浏览器内核与跨平台路径探测机制)
2. [Edge 核心特性与四大避坑铁律](#2-edge-核心特性与四大避坑铁律)
3. [控制方案一：构建标准 MCP 插件（Agent 原生首选）](#3-控制方案一构建标准-mcp-插件agent-原生首选)
4. [控制方案二：基于 Playwright / CDP 的无侵入直连驱动](#4-控制方案二基于-playwright--cdp-的无侵入直连驱动)
5. [控制方案三：Edge 原生扩展开发（Manifest V3 Bridge）](#5-控制方案三edge-原生扩展开发manifest-v3-bridge)
6. [Agent 操作 Edge 标准作业程序（SOP）](#6-agent-操作-edge-标准作业程序sop)
7. [异常处理与自愈矩阵（Troubleshooting）](#7-异常处理与自愈矩阵troubleshooting)

---

## 1. 浏览器内核与跨平台路径探测机制

Microsoft Edge 基于 **Chromium** 内核，100% 兼容 Chrome DevTools Protocol (CDP)。在执行任何自动化前，Agent 必须通过动态探测获取 Edge 真实执行路径，**严禁硬编码特定用户名目录**。

### 1.1 跨平台探测算法

#### Windows 环境
```powershell
# 1. 优先从系统环境变量命令查找
$edgeCmd = Get-Command msedge.exe -ErrorAction SilentlyContinue
if ($edgeCmd) { return $edgeCmd.Source }

# 2. 从标准 Program Files 路径回退检索
$candidates = @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:LocalAppData\Microsoft\Edge\Application\msedge.exe"
)
foreach ($path in $candidates) {
    if (Test-Path $path) { return $path }
}
```

#### macOS 环境
```bash
# 默认标准应用程序包路径
EDGE_PATH="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
if [ ! -f "$EDGE_PATH" ]; then
    EDGE_PATH=$(which msedge || which microsoft-edge)
fi
```

#### Linux 环境
```bash
# 标准发行版二进制名
which microsoft-edge-stable || which microsoft-edge || which msedge
```

---

## 2. Edge 核心特性与四大避坑铁律

### ⚠️ 铁律一：处置“启动增强 (Startup Boost)”常驻后台进程
* **机制**：Edge 在 Windows/macOS 上默认启用“启动增强”与“后台应用运行”。即使桌面上关闭了全部窗口，系统后台仍有无界面的 `msedge` 进程在驻留。
* **陷阱**：直接调用 `msedge --remote-debugging-port=9222` 时，新进程会将启动参数传递给后台已常驻的父进程并自我终止；但**父进程并未开启调试端口**，导致 9222 端口监听失败，后续所有 CDP 连接超时崩溃。
* **Agent 通用自愈动作**：
  1. 探测 `http://127.0.0.1:9222/json/version` 是否可访问；
  2. 若端口未响应，且检测到当前系统内只有无可视界面的后台 Edge 孤儿进程，先终止孤儿进程；
  3. 随后带调试参数启动。

### ⚠️ 铁律二：避免 User Data Profile 互斥锁冲突
* **日常登录态复用模式**：直接操控用户正在使用的 Edge（共享 Cookie、密码与会话）。必须让调试端口挂载在用户主实例上。
* **独立隔离沙盒模式**：若目标机器已有不可中断的 Edge 任务正在运行，Agent 应显式指定临时的 `--user-data-dir` 避免实例互斥锁碰撞：
  ```bash
  msedge --remote-debugging-port=9222 --user-data-dir="<TEMP_DIR>/edge_agent_profile"
  ```

### ⚠️ 铁律三：跨域源安全策略放行
* Chromium 111+ 对外部 WebSocket 连接实施了严格来源审查。启动 Edge 时务必追加参数：
  ```bash
  --remote-allow-origins=*
  ```
  否则外部脚本或 MCP 连接时会遭遇 `403 Forbidden`。

### ⚠️ 铁律四：静默自愈远程调试确认弹窗
* 部分新版 Chromium 首次侦测到外部 CDP 挂载时，会弹出系统原生确认框（*“要允许远程调试吗？”*）。
* Agent 应优先利用宿主环境的系统无障碍层（如 Accessibility API / 桌面控制工具）自动检索该弹窗并点击 `允许`，实现无人值守自愈。

---

## 3. 控制方案一：构建标准 MCP 插件（Agent 原生首选）

MCP（Model Context Protocol）是现代自主 Agent 的核心接入方式。

### 方案 1.1：通过 `chrome-devtools-mcp` 桥接 Edge
由于 Edge 与 Chrome 共用 CDP 协议，直接在 Agent 的 `mcp_config.json` 中配置即可：

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
*接入后 Agent 自动获得以下原子工具*：
- `navigate_page(url)`：页面导航
- `take_snapshot()`：获取页面无障碍树与交互元素 UID
- `click(uid)` / `fill(uid, value)`：基于 UID 精确交互
- `evaluate_script(function)`：执行 JavaScript
- `take_screenshot()`：页面截屏

---

### 方案 1.2：编写独立的通用 Edge MCP 服务（Python 示例）
当目标机器环境需要轻量、无 Node.js 依赖的自包含插件时，可使用 Python `mcp` 库快速搭建：

```python
# edge_mcp_server.py
import json
import httpx
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("edge-controller")
CDP_BASE = "http://127.0.0.1:9222"

@mcp.tool()
async def list_tabs() -> str:
    """获取 Edge 当前所有打开的标签页列表"""
    async with httpx.AsyncClient() as client:
        res = await client.get(f"{CDP_BASE}/json/list")
        tabs = [t for t in res.json() if t.get("type") == "page"]
        return json.dumps([{"id": t["id"], "title": t["title"], "url": t["url"]} for t in tabs], ensure_ascii=False)

@mcp.tool()
async def open_url(url: str) -> str:
    """在 Edge 中新建标签页并导航至目标网址"""
    async with httpx.AsyncClient() as client:
        res = await client.put(f"{CDP_BASE}/json/new?{url}")
        return f"标签页已创建: {res.json().get('id')}"

@mcp.tool()
async def close_tab(tab_id: str) -> str:
    """关闭指定的标签页"""
    async with httpx.AsyncClient() as client:
        res = await client.get(f"{CDP_BASE}/json/close/{tab_id}")
        return f"关闭状态: {res.text}"

if __name__ == "__main__":
    mcp.run()
```

---

## 4. 控制方案二：基于 Playwright / CDP 的无侵入直连驱动

当任务属于批处理、无需走 MCP 交互协议时，**通过 Playwright-core 或 CDP WebSocket 直连**是效率最高的方式。

### 核心原则
* **严禁调用 `playwright.chromium.launch()`**：这会开启全新空白沙盒窗口，丢失登录态且弹窗打扰用户。
* **统一使用 `chromium.connect_over_cdp()`**：静默挂载到已运行的 Edge 渲染引擎，**绝不抢占物理鼠标指针**。

### 通用控制器封装（Python）

```python
# edge_controller.py
import asyncio
from playwright.async_api import async_playwright

class EdgeController:
    def __init__(self, endpoint: str = "http://127.0.0.1:9222"):
        self.endpoint = endpoint
        self.pw = None
        self.browser = None

    async def __aenter__(self):
        self.pw = await async_playwright().start()
        self.browser = await self.pw.chromium.connect_over_cdp(self.endpoint)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.browser:
            await self.browser.close()
        if self.pw:
            await self.pw.stop()

    async def get_active_page(self, url_filter: str = None):
        """优先复用现有标签页，无匹配时新建"""
        contexts = self.browser.contexts
        if not contexts:
            raise RuntimeError("未检测到活跃浏览器上下文")
        pages = contexts[0].pages
        if url_filter:
            for page in pages:
                if url_filter in page.url:
                    await page.bring_to_front()
                    return page
        return await contexts[0].new_page()

    async def safe_extract(self, page, js_expression: str):
        """注入执行 JavaScript 提取结构化数据（防 Token 膨胀）"""
        return await page.evaluate(js_expression)

# 使用示例
async def run_task():
    async with EdgeController() as edge:
        page = await edge.get_active_page()
        await page.goto("https://www.bing.com", wait_until="domcontentloaded")
        
        # 模拟自然输入与回车
        await page.fill("textarea[name='q']", "AI Agent Automation")
        await page.press("textarea[name='q']", "Enter")
        await page.wait_for_selector("#b_results", timeout=5000)
        
        # 高效提取搜索列表
        results = await edge.safe_extract(page, """
            () => Array.from(document.querySelectorAll('#b_results > li.b_algo')).slice(0, 5).map(item => ({
                title: item.querySelector('h2')?.innerText?.trim(),
                url: item.querySelector('a')?.href
            }))
        """)
        print("提取结果:", results)
        
        # 资源清理：关闭临时标签
        await page.close()

if __name__ == "__main__":
    asyncio.run(run_task())
```

---

## 5. 控制方案三：Edge 原生扩展开发（Manifest V3 Bridge）

在无法开启系统调试端口（如内网受限主机）或需要长期驻留页面捕获内部网络请求时，可开发 Manifest V3 扩展，通过本地 WebSocket 与 Agent 进行双向桥接。

### 5.1 项目结构
```text
edge-agent-extension/
├── manifest.json
├── background.js
└── content.js
```

### 5.2 核心实现

#### `manifest.json`
```json
{
  "manifest_version": 3,
  "name": "Edge Agent Bridge",
  "version": "1.0.0",
  "description": "Agent Automation Bridge for Microsoft Edge",
  "permissions": ["activeTab", "scripting", "tabs", "storage"],
  "host_permissions": ["<all_urls>"],
  "background": {
    "service_worker": "background.js"
  }
}
```

#### `background.js`
```javascript
// 后台 Service Worker：连接本地 Agent 暴露的 WebSocket 服务端口
let ws = null;

function connectBridge() {
  ws = new WebSocket("ws://127.0.0.1:8765");

  ws.onopen = () => console.log("[Edge Extension] Connected to Agent host.");
  
  ws.onmessage = async (evt) => {
    const { id, action, tabId, payload } = JSON.parse(evt.data);
    try {
      if (action === "OPEN_URL") {
        const tab = await chrome.tabs.create({ url: payload.url });
        ws.send(JSON.stringify({ id, success: true, tabId: tab.id }));
      } else if (action === "EXECUTE_JS") {
        const [res] = await chrome.scripting.executeScript({
          target: { tabId: tabId },
          func: new Function(payload.script)
        });
        ws.send(JSON.stringify({ id, success: true, result: res.result }));
      }
    } catch (err) {
      ws.send(JSON.stringify({ id, success: false, error: err.message }));
    }
  };

  ws.onclose = () => setTimeout(connectBridge, 2000);
}

connectBridge();
```

---

## 6. Agent 操作 Edge 标准作业程序（SOP）

为保证操作的稳健性与资源整洁，Agent 在驱动 Edge 时必须严格执行以下 SOP：

### 1. 标签页生命周期与“借还即焚”原则
* **优先复用**：执行任务前先列出已有标签，命中目标域名则切换复用，禁止盲目无休止 `new_page`。
* **借还即焚**：因临时查询/提取而创建的标签页，任务完成后必须显式关闭（`close_page`）。

### 2. 批量数据提取防 Token 爆炸铁律
* **痛点**：对长列表、大页面执行完整无障碍快照（Snapshot）会吐出数万行 DOM 结构，瞬间撑爆 Agent 上下文。
* **铁律**：**所有数据提取优先使用 `evaluate_script` 直接提取结构化 JSON 数组**：
  ```javascript
  Array.from(document.querySelectorAll('.data-row')).map(row => ({
    name: row.querySelector('.name')?.innerText,
    value: row.querySelector('.val')?.innerText
  }));
  ```

### 3. SPA 异步等待防竞态
* 现代 Web 应用按钮点击后多为异步局部重绘，无整页刷新。
* **禁止点击后立即读取 DOM**；必须配合 `wait_for` 显式等待关键选择器出现，或轮询校验加载状态结束。

### 4. 人机验证处置分级闭环
* **L1 级（Cloudflare Turnstile / 简单勾选框）**：定位 checkbox 节点，触发 `click` 静默通过。
* **L2 级（滑块拼图 / 视觉缺口）**：
  1. 调用 `take_screenshot` 获取验证码截图；
  2. 使用多模态模型识别缺口偏移量 $\Delta x$；
  3. 通过缓动曲线（Bezier 拟人轨迹）模拟拖拽，禁止瞬间直线位移。
* **L3 级（短信验证码 / 扫码确认）**：识别鉴权边界，暂停并主动向人类用户请求凭据。

---

## 7. 异常处理与自愈矩阵（Troubleshooting）

| 故障现象 | 根源排查 | 自愈策略 |
| :--- | :--- | :--- |
| **`Connection Refused: 9222`** | 启动增强常驻进程拦截了启动参数 | 检查端口监听，终止无界面的残留 Edge 后台进程，重新带参数拉起 |
| **`403 Forbidden on WebSocket`** | Chromium 源安全策略拦截 | 启动参数补齐 `--remote-allow-origins=*` |
| **点击元素无反应** | 存在全屏透明遮罩、Cookie 授权弹窗或嵌套在 `iframe` 中 | 注入 JS 关闭浮窗；或穿透 `iframe.contentDocument` 进行点击 |
| **页面已跳转但抓取到旧数据** | SPA 异步请求未完成，命中旧 DOM 缓存 | 增加对骨架屏/加载指示器消失的显式等待逻辑 |
| **多 Profile 互斥崩溃** | 默认目录已被主进程独占 | 追加 `--user-data-dir="<临时路径>"` 分离运行时目录 |
