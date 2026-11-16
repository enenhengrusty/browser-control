"""
edge_driver_example.py
Connect directly to a running Microsoft Edge (or Chrome) instance over CDP using Playwright.
Shares the user's active profile/cookies without opening a blank sandbox browser.
"""

from __future__ import annotations

import argparse
import asyncio
import sys

from playwright.async_api import async_playwright


async def test_cdp_connection(port: int) -> None:
    endpoint = f"http://127.0.0.1:{port}"
    print(f"[*] Connecting to browser over CDP: {endpoint} ...")
    try:
        async with async_playwright() as p:
            browser = await p.chromium.connect_over_cdp(endpoint)
            contexts = browser.contexts
            if not contexts:
                print("[-] Error: No active browser context found.", file=sys.stderr)
                return

            context = contexts[0]
            print(f"[+] Connected! Active tabs: {len(context.pages)}")

            page = await context.new_page()
            try:
                print("[*] Navigating to https://www.bing.com ...")
                await page.goto("https://www.bing.com", wait_until="domcontentloaded")
                title = await page.title()
                print(f"[+] Loaded page title: {title!r}")

                data = await page.evaluate(
                    "() => ({ title: document.title, url: location.href })"
                )
                print(f"[+] Extracted structured data: {data}")
            finally:
                await page.close()
                print("[+] Temporary tab closed cleanly.")

    except Exception as e:
        print(f"[-] Failed to connect or drive browser via CDP: {e}", file=sys.stderr)
        print(
            "[-] Hint: Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\ensure_edge_cdp.ps1` first.",
            file=sys.stderr,
        )
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Playwright CDP connection example for Edge/Chrome")
    parser.add_argument("--port", type=int, default=9222, help="CDP debugging port (default: 9222)")
    args = parser.parse_args()
    asyncio.run(test_cdp_connection(args.port))


if __name__ == "__main__":
    main()
