# 音键发布说明

最后更新：2026-04-23

## 1. 发布策略

当前仓库发布：

- 源码
- GitHub Releases 中的 macOS 编译产物
- 设计文档
- 架构文档
- 编译说明
- 权限说明

当前仓库不发布：

- 本地签名证书
- 本地私钥
- 本地 API Key

说明：

- GitHub Release 现在走正式的 `Developer ID + notarization` 链路。
- GitHub 版和未来的 Mac App Store 版不是同一个最终分发包。
- GitHub 版优先保留辅助功能直写当前输入框的能力，App Store 版会单独收口沙盒和功能边界。

## 2. 如何从源码编译

前提：

- macOS
- Xcode
- 阿里云百炼 API Key

### 2.1 本地调试构建

```bash
xcodebuild -project voiceKey.xcodeproj \
  -scheme voiceKey \
  -configuration Debug \
  -derivedDataPath .derived \
  build
```

### 2.2 正式 GitHub 发布构建

前提：

- 本机已经安装 `Developer ID Application`
- 已经配置 `notarytool` 凭据

先存一次 notarization 凭据：

```bash
APPLE_ID="你的 Apple ID" \
APP_SPECIFIC_PASSWORD="你的 app-specific password" \
bash scripts/store_notary_credentials.sh
```

然后执行正式构建：

```bash
bash scripts/build_github_release.sh
```

正式产物默认在：

```text
dist/
├── voiceKey-1.0.5-macos.dmg
├── voiceKey-1.0.5-macos.dmg.sha256
├── voiceKey-1.0.5-macos.zip
└── voiceKey-1.0.5-macos.zip.sha256
```

脚本会自动完成：

- `GitHubRelease` 配置归档
- `Developer ID Application` 导出
- app bundle notarization
- app stapling
- DMG 构建
- DMG notarization
- DMG stapling
- SHA-256 生成

## 3. API Key

本项目使用阿里云百炼：

- `qwen3-asr-flash`
- `qwen-flash`

API Key 不会写进仓库。  
运行后在设置页里填入你自己的百炼 `API Key` 即可。`1.0.5` 开始不会自动读取钥匙串，只有用户手动点 `读取已保存 Key` 时才会访问本机安全存储。

普通用户请优先参考：

- [用户使用手册](./user-guide.md)

## 4. 权限说明

### 4.1 麦克风

作用：

- 录音

不开就不能说话录制。

### 4.2 辅助功能

作用：

- 获取当前焦点输入位置
- 把整理后的文本写回当前输入框

不开的话，音键会自动回退到剪贴板，结果仍然能得到，但不会自动落到当前输入框。

### 4.3 键盘监听

作用：

- 监听 `Fn` / 右侧 `⌥` 这类全局单键触发

当前 GitHub 直装版默认触发键是：

`Fn` 和 `Fn + Control`

大多数机器上会直接尝试注册；如果个别机器收不到 `Fn`，再手动打开键盘监听。

## 5. GitHub 正式分发与 Apple Store 的区别

这两个不是同一个最终产物。

### 5.1 GitHub 直装版

- 签名：`Developer ID Application`
- 分发：GitHub Releases
- 校验：Apple notarization
- 产物：`DMG` 和 `ZIP`
- 目标：让普通用户从 GitHub 下载后直接安装
- 能力边界：优先保留辅助功能直写当前输入框

### 5.2 Mac App Store 版

- 签名和审核：走 App Store Connect
- 分发：Mac App Store
- 沙盒：必须单独收口
- 功能边界：很可能和 GitHub 版不同

### 5.3 本地调试版

- 签名：`Apple Development`
- 用途：开发、调试、权限排查
- 不用于公开 GitHub 分发

## 6. 苹果编译与本地调试签名说明

项目里仍然保留本地调试签名脚本，主要是为了处理开发阶段的：

- Xcode 重编后的本地签名
- 权限稳定性
- 重复安装与调试

当前仓库保留了本地签名脚本，但不会公开任何证书和密码。

如果你使用 `vibe coding` 方式接手项目，这部分可以按文档来做，不需要自己重新发明一套签名流程。

如果你确实要自己处理本地签名，先看：

- [Vibe Coding 开发说明](./vibe-coding-guide.md)

当前调试安装脚本会优先尝试使用 `login.keychain-db` 里的 `Apple Development` 身份；如果这台机器还没有苹果正式证书，才会回退到仓库原有的本地开发签名脚本。

## 6. 界面预览素材建议

如果你要把仓库整理成更适合浏览的 GitHub 主页，推荐配这几类图：

1. 设置页截图
2. 录音态截图
3. 思考中截图
4. 一段短 GIF，展示 `按住说话 -> 松开 -> 出字`

当前仓库已有 HTML 原型，可作为预览参考：

- `prototypes/floating-orb/index.html`
- `prototypes/ui-states/index.html`

## 7. 公开仓库前必须确认的清单

1. `.derived` 不进入仓库
2. `codesign/` 下的证书和私钥不进入仓库
3. 本地 API Key 不进入仓库
4. README 使用外部名称 `音键`
5. Release 不包含任何本地证书和私钥

## 8. 当前推荐的公开方式

推荐：

- GitHub 仓库公开源码
- GitHub Release 提供 notarized `DMG`、备用 `ZIP` 和使用手册

当前不推荐：

- 把本地签名证书或 API Key 打包进仓库或 Release
- 把本地调试版 `Apple Development` 包直接发给普通用户
