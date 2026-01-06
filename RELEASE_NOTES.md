**[English](#english) | [中文](#中文)**

<a id="english"></a>

## English

### v1.0.1 - Native Windows Cursor Conversion

**Major Update: Windows cursor conversion rewritten from Python to native Swift**

- Replaced external Python script with pure Swift implementation. The snake has left the building
- No longer requires bundled Python runtime, unified into single version (previously Premium version include Python). Democracy has been restored
- Significantly reduced app size (from ~50MB to ~5MB). Your SSD will thank you
- Faster conversion speed with optimized performance. Gotta go fast
- Improved parsing reliability for .cur and .ani formats. We actually read the file headers now, who knew that was important

**New Features:**

- Add Windows install.inf parser for automatic cursor type mapping. No more manual labor, let the robots do it
- Add support for legacy Windows cursor formats (16-bit RGB555/RGB565, 8-bit/4-bit/1-bit indexed, RLE compression). Your cursors from Windows 95 are welcome here
- Add transparent window toggle in appearance settings. For those who like to see through things
- Add GitHub Actions CI workflow for automated builds. The machines are taking over, but in a good way

**Improvements:**

- Backport to macOS 15 Sequoia with adaptive styling (Liquid Glass on macOS 26, Material on macOS 15). Thanks to @isandrel for the PR
- Convert mousecloak helper to ARC (Automatic Reference Counting) for better memory management. No more memory leaks, probably
- Fix transparent window background for dark mode. The void stares back, but prettier now

**Bug Fixes:**

- Fixed memory alignment crash when parsing certain cursor files. Your cursor was trying to break free from its memory prison, we stopped it
- Fixed cape rename error when saving imported cursors. Names matter, even for cursor capes
- Fixed dark mode transparent window showing washed-out colors. The colors have been properly hydrated

> *Note: The author has been playing too much Goat Simulator lately. Baaaa~*

---

<a id="中文"></a>

## 中文

### v1.0.1 - 原生 Windows 光标转换

**重大更新：Windows 光标转换从 Python 重写为原生 Swift**

- 使用纯 Swift 实现替代外挂 Python 脚本。蟒蛇已经离开了建筑
- 不再需要内置 Python 环境，统一为单一版本（此前 Premium 版本内置 Python）。民主已经恢复
- 大幅减小应用体积（从约 50MB 降至约 5MB）。你的硬盘会感谢你的
- 优化性能，转换速度更快。要快，非常快
- 提升 .cur 和 .ani 格式的解析可靠性。我们现在真的会读文件头了，谁知道这很重要呢

**新功能：**

- 添加 Windows install.inf 解析器，自动识别光标类型映射。不再需要手动劳作，让机器人来干活
- 支持旧版 Windows 光标格式（16 位 RGB555/RGB565、8/4/1 位索引色、RLE 压缩）。欢迎你的 Windows 95 光标来此安家
- 在外观设置中添加透明窗口开关。给那些喜欢透视的人准备的
- 添加 GitHub Actions CI 工作流，实现自动化构建。机器正在接管，但是是好的那种

**改进：**

- 向下兼容 macOS 15 Sequoia，支持自适应样式（macOS 26 使用液态玻璃，macOS 15 使用 Material）。感谢 @isandrel 的 PR 贡献
- 将 mousecloak 辅助程序转换为 ARC（自动引用计数），改善内存管理。不再有内存泄漏了，大概吧
- 修复深色模式下透明窗口背景。虚空在凝视着你，但现在更好看了

**Bug 修复：**

- 修复解析某些光标文件时的内存对齐崩溃问题。你的光标试图从内存监狱中逃脱，我们阻止了它
- 修复导入光标保存时的 cape 重命名错误。名字很重要，即使是对光标披风来说
- 修复深色模式透明窗口显示颜色失真问题。颜色已经被适当地补水了

> *注：作者最近《模拟山羊》玩多了。咩～*

---

## Credits | 致谢

- **Original Author | 原作者:** Alex Zielenski (2013-2025)
- **SwiftUI Redesign | SwiftUI 重构:** sdmj76 (2025)
- **Coding Assistant | 编程协助:** Claude Code (Opus)
- **macOS 15 Backport | macOS 15 向下兼容:** @isandrel
