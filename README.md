# QuickOCR

macOS 菜单栏常驻小工具：按 **⌘1** 框选屏幕区域，识别其中的文字，直接复制到剪贴板，不弹窗、不驻 Dock。

- 本地优先：Apple Vision（`zh-Hans` + `en-US`，accurate 模式）
- 识别为空时回落云端：调用外部脚本 `~/skills/ocr-vision/cs-ocr.py`（可选，不随本仓库分发）
- 识别结果以 HUD 提示字数，无界面窗口

## 编译

```bash
./build.sh          # 生成 QuickOCR.app，ad-hoc 签名
```

要求 macOS 13+ 与 Xcode Command Line Tools（`swiftc`）。

## 安装与开机自启

拷到「应用程序」后直接打开一次，之后用 LaunchAgent 常驻：

```bash
cp -R QuickOCR.app /Applications/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.gao.quickocr.plist
```

`~/Library/LaunchAgents/com.gao.quickocr.plist` 里 `ProgramArguments` 指向 app 内的可执行文件，`RunAtLoad` 为 true。改路径后需 `bootout` 再 `bootstrap`。

## 权限

首次框选会请求「屏幕录制」权限，需在「系统设置 → 隐私与安全性 → 屏幕录制」中勾选 QuickOCR，否则截图为空。⌘1 走 Carbon 热键，不需要辅助功能权限。

## 命令行用法

```bash
QuickOCR.app/Contents/MacOS/QuickOCR --file screenshot.png
```

直接输出识别文本，不驻留、不注册热键，可用于脚本批处理。
