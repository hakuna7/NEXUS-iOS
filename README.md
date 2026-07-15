# NEXUS

NEXUS 是为非越狱 iPhone 设计的中文视觉智能控制中心，目标系统为 iOS 17 及以上。项目包含 iPhone 主程序、屏幕广播识别扩展和 Windows 空间遥控配套程序。

## 第一版功能

- 读取其他 App 的屏幕广播，在本机使用 Vision OCR 识别文字
- 翻译、页面解释、内容总结和风险分析四种看屏模式
- 画中画悬浮结果窗口
- 本地屏幕文字时间轴，不保存原始屏幕图片
- AI 对话与设备执行分离，执行前必须二次确认
- AR 物体分类、文字识别和中心距离估算
- 自动识别人脸、二维码和敏感号码并生成打码图片
- iPhone 陀螺仪控制 Windows 鼠标、媒体、锁屏和剪贴板

## 隐私

- API Key 存储在 iOS Keychain 中，不进入仓库或屏幕记忆。
- 屏幕 OCR 在设备本地完成。
- 只有启用 AI 功能时，识别出的文字才会发送到用户配置的兼容接口。
- 录屏由用户通过 iOS 系统面板主动开始，应用无法隐藏录屏状态。

## 构建

项目使用 XcodeGen。推送到 `main` 后，GitHub Actions 会生成：

- `NEXUS-iOS-unsigned`：可交给 SideStore 签名的 IPA
- `NEXUS-Windows-Bridge`：Windows 配套程序

本地 macOS 构建：

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project NEXUS.xcodeproj -scheme NEXUS -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

## 安装说明

NEXUS 带有屏幕广播扩展，应通过 SideStore 作为独立 App 安装，不应导入 LiveContainer。首次使用实时看屏时：

1. 在“看屏”页面开启画中画。
2. 点击录屏图标。
3. 在 iOS 系统面板选择“NEXUS 屏幕识别”。
4. 切换到需要翻译或解释的 App。

受 DRM 保护的视频、银行应用或主动禁止录屏的页面可能返回黑屏。
