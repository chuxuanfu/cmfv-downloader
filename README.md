# CMFV/CMFA 视频下载器

Apple CMAF 格式视频的自动化下载和合并工具。

## 📝 简介

这是一个用于下载和合并 Apple CMAF（Common Media Application Format）格式视频的脚本。CMAF 是一种分段媒体格式，视频被分割成多个小文件（.cmfv 视频，.cmfa 音频，.vtt 字幕），需要下载后拼接。

## ✨ 功能特性

- ✅ **并发下载** - 支持多线程下载，速度快
- ✅ **断点续传** - 中断后重新运行会跳过已下载的分段
- ✅ **自动拼接** - 自动合并视频、音频和字幕
- ✅ **容错处理** - 部分下载失败也能继续
- ✅ **灵活配置** - 只需修改顶部配置区域

## 🎯 适用场景

适用于下载以下格式的视频：
- Apple 发布会视频（CMAF 格式）
- 其他使用 CMFV/CMFA 分段的流媒体视频

## 📦 文件说明

```
cmfv-downloader/
├── download_merge.sh    # 主下载脚本
├── README.md            # 使用说明（本文件）
└── USAGE.md             # 详细使用指南
```

## 🚀 快速开始

### 前置要求

1. **ffmpeg** - 用于合并视频
```bash
brew install ffmpeg
```

2. **curl** - 下载工具（macOS 自带）

### 基本用法

1. **打开脚本配置区域**

编辑 `download_merge.sh`，修改顶部的配置：

```bash
# ========== 分段范围 ==========
START_SEGMENT=1          # 起始编号
END_SEGMENT=528          # 结束编号（需要根据实际情况调整）
NUM_DIGITS=9             # 编号位数

# ========== Init Segment URL ==========
INIT_VIDEO_URL="https://..../1080pinit.cmfv"
INIT_AUDIO_URL="https://..../ENG_1init.cmfa"

# ========== 分段 URL 模板 ==========
VIDEO_URL_TEMPLATE="https://..../1080p_{NUM}.cmfv"
AUDIO_URL_TEMPLATE="https://..../ENG_1_{NUM}.cmfa"
VTT_URL_TEMPLATE="https://..../en-US_{NUM}.vtt"

# ========== 下载设置 ==========
CONCURRENT_JOBS=10       # 并发下载数
OUTPUT_NAME="final_video" # 输出文件名
```

2. **运行脚本**

```bash
cd /Users/chuxuanfu/cmfv-downloader
./download_merge.sh
```

3. **等待完成**

脚本会自动：
- 下载 init 文件
- 并发下载所有分段
- 验证完整性
- 拼接视频
- 合并字幕（如果有）
- 使用 ffmpeg 生成最终的 MP4 文件

## 📊 工作流程

```
Step 0: 下载 Init Segment
   ├─ 下载视频 init (1080pinit.cmfv)
   └─ 下载音频 init (ENG_1init.cmfa)

Step 1: 生成下载列表
   ├─ 检查已存在的分段
   └─ 生成待下载 URL 列表

Step 2: 并发下载 (默认10线程)
   ├─ 下载视频分段 (1080p_000000001.cmfv ~ 1080p_000000528.cmfv)
   ├─ 下载音频分段 (ENG_1_000000001.cmfa ~ ENG_1_000000528.cmfa)
   └─ 下载字幕分段 (en-US_000000001.vtt ~ en-US_000000528.vtt)

Step 3: 验证完整性
   └─ 检查所有分段是否下载成功

Step 4: 拼接分段
   ├─ 拼接视频：init + seg_1 + seg_2 + ... + seg_N
   └─ 拼接音频：init + seg_1 + seg_2 + ... + seg_N

Step 5: 合并字幕
   └─ 将所有 VTT 字幕片段合并为一个文件

Step 6: ffmpeg 混流
   └─ 合并视频 + 音频 + 字幕 → final_video.mp4
```

## ⚙️ 配置说明

### 分段范围

```bash
START_SEGMENT=1          # 第一个分段编号
END_SEGMENT=528          # 最后一个分段编号
NUM_DIGITS=9             # 编号补零位数（9 表示 000000001）
```

**如何确定 END_SEGMENT？**
- 方法1: 查看源网页的 manifest 文件
- 方法2: 手动测试，逐步增加直到 404
- 方法3: 使用浏览器开发者工具查看网络请求

### URL 模板

使用 `{NUM}` 作为占位符，会被替换为补零后的编号：

```bash
VIDEO_URL_TEMPLATE="https://example.com/video_{NUM}.cmfv"
# 实际下载: video_000000001.cmfv, video_000000002.cmfv, ...
```

### 并发设置

```bash
CONCURRENT_JOBS=10       # 同时下载的分段数
```

**建议值：**
- 网速快：15-20
- 网速一般：10
- 网速慢：5
- 服务器限流：3-5

## 🔄 断点续传

如果下载中断：

```bash
# 直接重新运行即可
./download_merge.sh
```

脚本会：
- ✅ 自动检测已下载的分段
- ✅ 只下载缺失的部分
- ✅ 从上次进度继续

## 📂 输出文件

运行完成后会生成：

```
cmfv-downloader/
├── final_video.mp4      # 最终合并的视频
├── final_video.vtt      # 字幕文件（如果字幕无法嵌入）
└── segments/            # 临时文件夹
    ├── video/           # 视频分段
    ├── audio/           # 音频分段
    ├── subtitle/        # 字幕分段
    ├── merged_video.cmfv
    ├── merged_audio.cmfa
    └── merged_subtitle.vtt
```

完成后可以删除 `segments/` 目录释放空间。

## ⚠️ 常见问题

### Q: 如何找到 URL？

A: 使用浏览器开发者工具：

1. 打开视频网页
2. 按 F12 打开开发者工具
3. 切换到 Network（网络）标签
4. 播放视频
5. 查找 `.cmfv` 或 `.cmfa` 请求
6. 复制 URL，提取模板

### Q: 下载速度慢？

A: 尝试：
- 增加 `CONCURRENT_JOBS` (例如 15 或 20)
- 检查网络连接
- 检查服务器是否限速

### Q: 部分分段下载失败？

A: 
1. 重新运行脚本（会自动重试）
2. 减少 `CONCURRENT_JOBS`（避免被限流）
3. 手动下载失败的分段

### Q: ffmpeg 报错？

A: 
```bash
# 检查 ffmpeg 是否安装
ffmpeg -version

# 安装 ffmpeg
brew install ffmpeg
```

### Q: 字幕无法嵌入？

A: 
- 视频会正常生成
- 字幕会保存为单独的 `.vtt` 文件
- 大多数播放器支持加载外部字幕

## 💡 高级用法

### 只下载视频（不下载音频）

将 `AUDIO_URL_TEMPLATE` 设置为空：

```bash
AUDIO_URL_TEMPLATE=""
```

### 只下载音频

将 `VIDEO_URL_TEMPLATE` 设置为空：

```bash
VIDEO_URL_TEMPLATE=""
```

### 不下载字幕

```bash
VTT_URL_TEMPLATE=""
```

### 自定义输出文件名

```bash
OUTPUT_NAME="my_video"  # 生成 my_video.mp4
```

## 🧹 清理临时文件

完成后手动清理：

```bash
rm -rf segments/
```

或在脚本最后选择 `y` 自动清理。

## 📊 典型下载时间

以 528 个分段为例（约 88 分钟视频）：

- **并发 10**: 约 10-15 分钟
- **并发 20**: 约 5-8 分钟
- 具体时间取决于网速和服务器速度

## 🛠️ 技术细节

### CMAF 格式说明

CMAF (Common Media Application Format) 是基于 fMP4 的流媒体格式：

- **Init Segment**: 包含初始化信息（编解码器、分辨率等）
- **Media Segments**: 实际的视频/音频数据
- **拼接方式**: 二进制拼接（cat init.cmfv seg_*.cmfv）

### 为什么不直接用 ffmpeg 下载？

- CMAF 使用分段存储，ffmpeg 无法直接处理
- 需要先下载所有分段，再手动拼接
- 本脚本自动化了整个流程

## 📄 许可

MIT License

---

**祝你使用愉快！** 🎬
