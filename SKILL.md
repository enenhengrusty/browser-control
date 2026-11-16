---
name: browser-control
description: 网页操作与浏览器自动化控制（支持 Google Chrome 与 Microsoft Edge）：涉及日常浏览、登录态业务（学校/邮箱/平台系统）、查阅文献、用户要求查看/点击网页时，通过 Chrome DevTools (CDP) 原生指令直接操控用户日常运行的可视化浏览器，严禁拉起可视化空白沙盒窗口打扰用户；而在本机开发调试、本地前端测试（如 localhost）、无状态测试套件或离线批处理时，允许并推荐使用无头浏览器 (Headless)。具备轻量化数据提取、SPA 异步等待、PDF/下载边界处置及【无人值守人机验证自主解决】能力。
---

# 可视化浏览器自动化 (Browser Control)

本技能通过 `chrome-devtools` MCP（Chrome DevTools Protocol, CDP）直接与用户日常使用的 **Google Chrome** 或 **Microsoft Edge**（均基于 Chromium 渲染引擎）通信。它直接接入用户电脑上正在运行的真实浏览器实例，**完全继承用户的全部日常登录态、Cookie 与书签**，并且**绝不抢占或移动用户的物理鼠标指针**，实现静默高效的人机协同与全自动运行。

---

## 🎯 浏览器使用场景与选型准则（灵活适配，不搞教条）

| 场景类型 | 典型任务 | 推荐方案 | 核心原则 |
| :--- | :--- | :--- | :--- |
| **日常网页操作与登录态业务** | 查资料、开网页、操作校园网/邮箱/文献库/后台系统、替用户点击填表 | **用户日常 Chrome / Edge** (`chrome-devtools` MCP) | **直接继承用户的日常登录态、Cookie 与书签**；严禁拉起带有独立临时 Profile 的可视化空白沙盒窗口打扰用户。 |
| **本机开发调试与自动化测试** | 本地开发服务 (`localhost:3000`) 调试、E2E 测试套件、CI 流水线、公开静态页无状态批量采集、HTML 转 PDF/截图 | **无头浏览器** (Playwright / Puppeteer `headless=True`) | **完全允许并推荐使用无头模式**！执行极速、环境干净隔离、不污染用户日常标签页与浏览历史。 |

---

### 1. 日常网页与登录态业务规范（接入用户日常 Chrome / Edge）

1. **优先接入正在运行的日常浏览器**：
   - 涉及需要用户登录态、特定账号权限、或用户明确要求“帮我打开/查看某网页”的操作，**必须直接使用 `chrome-devtools` / `edge-devtools` MCP 工具链**（如 `list_pages`、`select_page`、`new_page`、`navigate_page`、`take_snapshot`、`click`、`fill`、`evaluate_script` 等）。
2. **未连接 Chrome 时的自动唤醒流程**：
   - 若 `list_pages` 提示无法连接到 Chrome（用户尚未开启 Chrome）：
     1. 自动探测 Chrome 可执行路径（Windows 常见位置：`%ProgramFiles%\Google\Chrome\Application\chrome.exe`、`%LocalAppData%\Google\Chrome\Application\chrome.exe`）或运行本技能附带的 `scripts/ensure_chrome_cdp.ps1`，也可通过桌面控制工具（如 [`computer-use-v2`](https://github.com/enenhengrusty/computer-use-v2) 的 `launch_app`）启动；
     2. 启动后等待 1~2 秒，检查是否出现 Chromium 原生授权弹窗（`要允许远程调试吗？` / `Allow remote debugging?`）；
     3. 若出现，立即通过桌面控制工具的 UIA 无障碍树定位并点击 `[允许]` / `[Allow]` 按钮；
     4. 随后恢复 `chrome-devtools` 交互，实现全自动唤醒与无感接入。
3. **接入 Microsoft Edge 的标准流程（避开 Startup Boost 陷阱）**：
   - Edge 与 Chrome 共用 CDP 协议，使用 `chrome-devtools-mcp` 时需在 MCP 配置中指定 `--browser-url=http://127.0.0.1:9222`。
   - **重要陷阱**：Edge 默认开启“启动增强 (Startup Boost)”，关闭窗口后后台仍驻留无界面 `msedge.exe` 进程，直接追加 `--remote-debugging-port=9222` 会被后台进程吞掉参数。
   - **标准唤醒**：优先运行本技能附带的 `scripts/ensure_edge_cdp.ps1`（自动检测并清理无界面孤儿后台进程、带上 `--remote-debugging-port=9222 --remote-allow-origins=*` 启动 Edge，并校验端口就绪）。

### 2. 本机开发调试与测试规范（灵活使用无头 Headless）
- 在编写自动化测试脚本（如 `pytest` + Playwright、`bun test` 等）、测试本地前端组件、跑 E2E 流程或做纯离线渲染时：
  - **无需拘泥于主浏览器**，可直接编写脚本调用 `playwright.chromium.launch(headless=True)`；
  - 务必确保是 **无头模式 (`headless=True`)**，防止在桌面上弹出可视化空窗口打扰用户工作。

---

## 核心机制：指令调用 vs 物理桌面模拟

| 维度 | 本技能（CDP DevTools 指令） | 桌面控制（如 Computer-Use v2） |
| :--- | :--- | :--- |
| **工作原理** | 通过 CDP 协议直接操作 DOM / 无障碍树 | 抓取屏幕图像 / UIA 树，驱动光标与输入 |
| **浏览器对象** | **用户日常主 Chrome / Edge 实例**（共享登录态） | 识别当前桌面可视区域 |
| **鼠标状态** | **完全不占用物理鼠标**，后台静默操作 | 在屏幕上移动虚拟/物理光标执行操作 |
| **抗干扰度** | 窗口被遮挡、页面滚动、高 DPI 均不受影响 | 窗口被遮挡或滚动可能导致坐标偏移 |
| **适用边界** | **网页内部的一切常规操作（导航、填表、点击、提取）** | **滑块拖拽破解、系统原生弹窗、跨桌面软件联动** |

---

## 标签页生命周期与资源卫生管理（Tab Lifecycle）

为防止后台无节制打开新标签页导致用户浏览器内存爆炸及 Target 混乱，执行以下纪律：

1. **优先复用原则**：
   - 执行任务前先调用 `list_pages`。若已有目标网站或匹配 URL 的标签页，使用 `select_page` 切换并直接复用，避免重复打开。
2. **临时标签“借还即焚”原则**：
   - 若因临时查询、检索或抓取数据而调用 `new_page` 创建了新标签页，**必须记录其 `page_id` / `targetId`**；
   - 任务完成后，**必须显式调用 `close_page` 关闭该临时标签页**，保持用户浏览器整洁清爽。
3. **多标签页上下文锁定**：
   - 当浏览器存在多个标签页时，每次执行关键交互前必须确保当前选中的是目标标签页；需要切换时明确调用 `select_page`。

---

## 基本操作循环与数据提取规范（防 Token 爆炸）

### 1. 交互与填表循环（常规操作）
1. **就绪确认**：使用 `take_snapshot` 获取页面的无障碍语义树及每个可交互元素的唯一 `uid`。
2. **精准操作**：使用元素 `uid` 执行 `click`、`fill`、`press_key` 等动作。禁止使用坐标盲点。

### 2. 批量数据提取规范（严禁无障碍树倒灌）
* **痛点**：对于文献列表、搜索结果、后台表格等大页面，调用 `take_snapshot` 会返回上万行文本，瞬间撑爆上下文并带来大量噪声。
* **准则**：**提取网页数据优先使用 `evaluate_script` 直接提取结构化 JSON**！
  ```javascript
  // 示例：从论文检索或搜索结果中批量提取结构化数据
  const items = Array.from(document.querySelectorAll('.result-item, .search-result')).map(el => ({
    title: el.querySelector('h3, .title')?.innerText?.trim(),
    link: el.querySelector('a')?.href,
    desc: el.querySelector('.abstract, .snippet')?.innerText?.trim()
  }));
  items;
  ```
  直接返回精炼的 JSON 数组，速度快且仅消耗极少 Token。

### 3. 虚拟列表与无限滚动（Infinite Scroll）
* 面对分页采用懒加载或滚动追加的网页，不要在原地盲目 snapshot：
* 通过 `evaluate_script` 触发平滑滚动：`window.scrollBy({top: 1000, behavior: 'smooth'});`
* 等待 1~2 秒网络请求完成，再检测 DOM 节点新增情况。

---

## 现代 SPA 异步等待与状态防竞态（Anti-Race Condition）

在 Vue / React / Next.js 等单页应用中，点击按钮往往是异步局部重绘，无全页刷新：
1. **禁止点击后立即 snapshot**：刚点击按钮立即调用 `take_snapshot` 会捕获到尚未渲染的旧 DOM，导致误判为“操作失败”而重复盲点。
2. **显式等待机制**：
   - 优先使用 `wait_for` 指定期望出现的新元素或文本；
   - 或者使用 `evaluate_script` 轮询检查目标状态是否就绪：
     ```javascript
     await new Promise((resolve) => {
       const check = () => {
         if (document.querySelector('.success-message') || !document.querySelector('.loading-spinner')) resolve(true);
         else setTimeout(check, 300);
       };
       check();
     });
     ```

---

## 人机验证双轨体系：协同模式 vs 无人值守自主解决

人机验证分为 **常规人机协同模式** 与 **无人值守/用户不便时的自主解决模式**。

### 1. L1 级：单点确认型质询（全自动静默通过）
* **场景**：Cloudflare Turnstile、普通单点复选框（*“请确认您是真人”* / *“Verify you are human”* / 5 秒盾复选框）。
* **自主解决 SOP**：
  1. 调用 `take_snapshot`，在无障碍树中定位质询复选框（通常位于 `Iframe` 下的 `checkbox` 节点）；
  2. 调用 `click` 直接点击该节点的 `uid`；
  3. 等待 2~3 秒，重新确认页面已跳转并继续任务，**全程无需打扰用户**。

### 2. L2 级：复杂交互型验证（滑块拼图 / 图素点选 / 旋转角度）

#### 策略 A：用户在身边时的常规协同模式 (Human-in-the-Loop)
在用户未指定“不在身边/全自动”时，优先保持友好协同：
- 明确通知用户：*“当前页面需要完成滑块拼图验证，已为你保留在浏览器中，请顺手滑动一下，完成后回复我即可。”*
- 用户回复后立即刷新状态继续。

#### 策略 B：无人值守自主解决模式 (Autonomous Solver)
**触发条件**：用户明确提出“我不方便 / 不在电脑前 / 全自动搞定 / 无人值守运行”，或协同等待超时。

**自主解决实战 SOP**（需联动桌面控制工具，如 `computer-use-v2`）：
1. **捕获验证码靶区**：
   - 调用 `take_screenshot` 截取验证码弹窗画面；或使用 `evaluate_script` 提取验证码背景图与滑块小图位置。
2. **多模态视觉定位计算**：
   - **优先方式（Agent 内置多模态视觉理解）**：直接分析截图中标尺与缺口所在的相对偏移像素距离 `Δx`；
   - **离线备选（本地视觉模型，如 Ollama `minicpm-v:8b`）**：若环境部署了本地多模态模型（如 `http://localhost:11434/api/generate`），可传入截图请求缺口坐标。
3. **拟人化物理拖拽执行**：
   - **核心禁忌**：绝对不要用瞬间直线坐标跳转（会被风控判定为机器人轨迹直接拦截）！
   - **标准动作**：
     1. 通过 `take_snapshot` / `computer-use-v2:get_screen_state` 获取滑块滑钮的物理屏幕坐标 `(startX, startY)`；
     2. 目标坐标计算为 `(startX + Δx, startY)`；
     3. 调用 `computer-use-v2:drag(from_x=startX, from_y=startY, to_x=startX + Δx, to_y=startY)`，底层平滑贝塞尔曲线拖至目标点并释放。
4. **验证结果检测与熔断防护**：
   - 等待 1.5 秒，调用 `take_snapshot` 或执行 JS 检查验证码容器是否消失；
   - **熔断机制**：若失败，自主重试最多 **3 次**。超过 3 次立即停止并向用户告警，防止触发 IP 封锁。

### 3. L3 级：真外生凭据验证（鉴权边界）
* **场景**：手机短信动态验证码、微信/App 扫码登录、硬件 Key、高危资金支付密码。
* **边界原则**：此类凭据属于外生机密，Agent 严禁猜测或绕过，必须暂停并等待用户完成或提供。

---

## 特殊格式与边界逃逸规范

### 1. 内置 PDF 预览器处理（文献/报告）
* **痛点**：浏览器内置 PDF 插件不提供 HTML DOM，`take_snapshot` 只能看到一个空的 `<embed type="application/pdf">`。
* **破局 SOP**：
  1. 通过 `evaluate_script` 提取当前页面的原始 `.pdf` 下载 URL 与当前域名 Cookie（`document.cookie`）；
  2. 在有权限的情况下，通过终端脚本（如 Python `httpx` / `requests`）携带 Cookie 将 PDF 下载到临时目录；
  3. 使用 PDF 解析库（如 `PyMuPDF / fitz`）提取纯文本或解析内容，**严禁在 DevTools 里死磕 PDF 页面**。

### 2. 文件下载与另存为弹窗
* 当点击下载按钮触发了系统级“另存为”文件对话框时：
  1. DevTools 无法直接控制系统对话框，立刻移交桌面控制工具（如 `computer-use-v2`）处理；
  2. 或配置浏览器默认静默保存到用户下载目录（Windows：`%USERPROFILE%\Downloads`；macOS/Linux：`~/Downloads`）；
  3. 监控下载目录中新增文件及其大小，确认下载完成。

### 3. 嵌套 Iframe 穿透
* 很多高校教务系统、旧版企业内网将主体表单置于 `<iframe>` 中：
* 优先在 `take_snapshot` 中寻找 iframe 内部暴露的节点；
* 若无法直接操作，使用 `evaluate_script` 穿透：
  ```javascript
  const frame = document.querySelector('iframe')?.contentDocument;
  frame?.querySelector('#target-input')?.value;
  ```

---

## 页面就绪与干扰噪音清理（Cleanup SOP）

访问学术数据库（ScienceDirect、Springer、IEEE 等）或现代商业网站时，页面首次加载常伴随全屏遮罩：
1. **GDPR / Cookie 同意框**；
2. **新特性引导 / 营销模态浮窗**。

* **标准清理动作**：页面加载后，主动通过 `evaluate_script` 静默清理干扰：
  ```javascript
  const cookieBtn = document.querySelector('#onetrust-accept-btn-handler') ||
                    Array.from(document.querySelectorAll('button')).find(b => b.innerText.includes('Accept all cookies'));
  if (cookieBtn) cookieBtn.click();
  const closeBtn = Array.from(document.querySelectorAll('button')).find(b => b.innerText.trim() === 'Close' || b.getAttribute('aria-label') === 'Close');
  if (closeBtn) closeBtn.click();
  ```

---

## 自动消除远程调试安全弹窗（硬性自愈规范）

* **产生原理**：Chromium 128+ 在外部程序通过 CDP 首次挂载时，会弹出系统原生确认对话框（`要允许远程调试吗？` / `Allow remote debugging?`）。
* **自动处理流程（禁止打扰用户）**：
  1. 当启动浏览器或调用 `chrome-devtools` 遇到挂起时，立即调用桌面控制工具的 `list_windows`（如 `computer-use-v2:list_windows`）；
  2. 若检测到窗口标题为 `要允许远程调试吗？` 或 `Allow remote debugging?`，调用 `get_screen_state` 定位 `Button "允许"` / `Button "Allow"`；
  3. 调用 `click` 自动点击允许；
  4. 弹窗瞬间静默关闭，随后立即恢复 `chrome-devtools` 交互，用户全程无感知。
