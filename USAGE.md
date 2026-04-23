# CMFV 下载器详细使用指南

## 📖 完整使用流程

### 准备工作

#### 1. 安装依赖

```bash
# macOS
brew install ffmpeg

# 检查安装
ffmpeg -version
curl --version  # macOS 自带
```

#### 2. 获取视频 URL

使用浏览器开发者工具获取视频 URL：

**步骤：**

1. 打开要下载的视频页面（例如 Apple 发布会）
2. 按 `F12` 或 `右键 → 检查` 打开开发者工具
3. 切换到 `Network（网络）` 标签
4. 勾选 `Preserve log（保留日志）`
5. 刷新页面或播放视频
6. 在过滤框输入 `.cmfv` 或 `.cmfa`
7. 找到视频请求，例如：

```
https://fc-cdn-int.apple.com/applevideo/d169b6c0/d169b6c0_1776809163_1080p/1080p_000000001.cmfv
```

**提取模板：**

将数字部分替换为 `{NUM}`：

```
原始URL:
https://...../1080p_000000001.cmfv

模板:
https://...../1080p_{NUM}.cmfv
```

#### 3. 确定分段数量

**方法 1: 查看 manifest 文件**

在 Network 中查找：
- `master.m3u8`
- `playlist.m3u8`
- `manifest.json`

这些文件通常包含分段信息。

**方法 2: 手动测试**

使用 curl 测试：

```bash
# 测试第 1 个分段
curl -I "https://...../1080p_000000001.cmfv"

# 测试第 500 个分段
curl -I "https://...../1080p_000000500.cmfv"

# 测试第 600 个分段（如果返回 404 说明超出范围）
curl -I "https://...../1080p_000000600.cmfv"
```

### 配置脚本

编辑 `download_merge.sh`：

```bash
#!/bin/zsh
set -e

# ╔══════════════════════════════════════════════════════════════╗
# ║  只需要修改这个区域                                          ║
# ╚══════════════════════════════════════════════════════════════╝

# ---------- 分段范围 ----------
START_SEGMENT=1          # 从 1 开始
END_SEGMENT=528          # 根据实际情况修改
NUM_DIGITS=9             # 000000001 是 9 位

# ---------- Init Segment URL ----------
INIT_VIDEO_URL="https://fc-cdn-int.apple.com/.../1080pinit.cmfv"
INIT_AUDIO_URL="https://fc-cdn-int.apple.com/.../ENG_1init.cmfa"

# ---------- 分段 URL 模板 ----------
VIDEO_URL_TEMPLATE="https://fc-cdn-int.apple.com/.../1080p_{NUM}.cmfv"
AUDIO_URL_TEMPLATE="https://fc-cdn-int.apple.com/.../ENG_1_{NUM}.cmfa"
VTT_URL_TEMPLATE="https://gnv.apple.com/.../en-US_{NUM}.vtt"

# ---------- 下载设置 ----------
CONCURRENT_JOBS=10       # 并发数
OUTPUT_NAME="final_video" # 输出文件名

# ╔══════════════════════════════════════════════════════════════╗
# ║  配置结束                                                    ║
# ╚══════════════════════════════════════════════════════════════╝
```

### 运行下载

```bash
cd /Users/chuxuanfu/cmfv-downloader
./download_merge.sh
```

### 查看输出

下载过程中会显示：

```
============================================
  Step 0: 下载 Init Segment
============================================
  ✅ Video init OK (796B)
  ✅ Audio init OK (796B)

============================================
  Step 1: 生成下载列表 (#1 ~ #528, 共 528 个)
============================================
  ✅ 列表生成完毕

============================================
  Step 2: 并发下载 (max 10)
============================================
  📹 下载视频 (528 个)...
  📹 视频完成
  🔊 下载音频 (528 个)...
  🔊 音频完成
  📝 下载字幕 (528 个)...
  📝 字幕完成

============================================
  Step 3: 验证完整性
============================================
  视频: 528 / 528
  音频: 528 / 528
  字幕: 528 / 528

============================================
  Step 4: 拼接分段
============================================
  📹 拼接视频...
  ✅ 视频: 3.2G
  🔊 拼接音频...
  ✅ 音频: 95M

============================================
  Step 5: 合并字幕
============================================
  ✅ 字幕合并完成 (528 段)

============================================
  Step 6: ffmpeg 混流
============================================
  🎬 生成 final_video.mp4 ...
  ✅ 合并成功（含字幕）

============================================
  🎉 完成！
  文件: final_video.mp4
  大小: 3.3G
============================================

删除临时文件? (y/n)
```

## 🎯 实战示例

### 示例 1: 下载 Apple 发布会

```bash
# 1. 配置
START_SEGMENT=1
END_SEGMENT=719
NUM_DIGITS=9

INIT_VIDEO_URL="https://fc-cdn-int.apple.com/applevideo/xxx/1080pinit.cmfv"
INIT_AUDIO_URL="https://fc-cdn-int.apple.com/applevideo/xxx/ENG_1init.cmfa"

VIDEO_URL_TEMPLATE="https://fc-cdn-int.apple.com/applevideo/xxx/1080p_{NUM}.cmfv"
AUDIO_URL_TEMPLATE="https://fc-cdn-int.apple.com/applevideo/xxx/ENG_1_{NUM}.cmfa"
VTT_URL_TEMPLATE="https://gnv.apple.com/xxx/en-US_{NUM}.vtt"

CONCURRENT_JOBS=15
OUTPUT_NAME="apple_event_2024"

# 2. 运行
./download_merge.sh
```

### 示例 2: 只下载视频（无音频无字幕）

```bash
INIT_VIDEO_URL="https://...../1080pinit.cmfv"
INIT_AUDIO_URL=""  # 留空

VIDEO_URL_TEMPLATE="https://...../1080p_{NUM}.cmfv"
AUDIO_URL_TEMPLATE=""  # 留空
VTT_URL_TEMPLATE=""     # 留空

OUTPUT_NAME="video_only"
```

### 示例 3: 断点续传

```bash
# 第一次运行，下载了 200 个分段后网络中断
./download_merge.sh

# 恢复后，直接重新运行即可
./download_merge.sh
```

第二次运行时输出会显示：

```
============================================
  Step 1: 生成下载列表 (#1 ~ #528, 共 528 个)
============================================
  ✅ 列表生成完毕

============================================
  Step 2: 并发下载 (max 10)
============================================
  📹 下载视频 (328 个)...  # 只下载剩余的 328 个
```

## 🔧 故障排除

### 问题 1: curl: (22) The requested URL returned error: 404

**原因**: URL 不正确或分段不存在

**解决**:
1. 检查 URL 模板是否正确
2. 确认 `END_SEGMENT` 是否超出范围
3. 手动测试 URL：
   ```bash
   curl -I "https://...../1080p_000000001.cmfv"
   ```

### 问题 2: 部分分段下载失败

**症状**:
```
  视频: 520 / 528
  音频: 528 / 528
  
  ⚠️  部分下载失败！继续合并? (y/n)
```

**解决**:
1. 输入 `n` 退出
2. 重新运行脚本（会自动重试失败的分段）
3. 如果仍然失败，减少 `CONCURRENT_JOBS`（可能被限流）

### 问题 3: ffmpeg 报错

**症状**:
```
ffmpeg: command not found
```

**解决**:
```bash
brew install ffmpeg
```

### 问题 4: 合并后视频无声音

**原因**: 音频 URL 配置错误或下载失败

**检查**:
```bash
# 查看音频分段目录
ls -lh segments/audio/

# 检查音频 init
ls -lh segments/audio/init.cmfa

# 检查合并后的音频
ls -lh segments/merged_audio.cmfa
```

### 问题 5: 字幕无法嵌入

**现象**: 提示 "字幕另存: final_video.vtt"

**原因**: MP4 容器不兼容 VTT 字幕格式

**解决**: 使用外部字幕文件，大多数播放器支持：
- VLC: 拖放 `.vtt` 文件到播放器
- QuickTime: 使用 IINA 等第三方播放器

### 问题 6: 下载速度慢

**优化建议**:

1. 增加并发数：
   ```bash
   CONCURRENT_JOBS=20  # 或更高
   ```

2. 检查网络：
   ```bash
   # 测试下载速度
   curl -o /dev/null https://...../1080p_000000001.cmfv
   ```

3. 使用代理（如果服务器在国外）

## 📊 性能调优

### 并发数建议

| 网速 | 建议并发数 | 预计下载时间（500分段） |
|------|-----------|---------------------|
| 1 Gbps | 20-30 | 3-5 分钟 |
| 100 Mbps | 15-20 | 5-8 分钟 |
| 10 Mbps | 10-15 | 10-15 分钟 |
| < 10 Mbps | 5-10 | 15-30 分钟 |

### 磁盘空间

估算公式：

```
所需空间 = 分段数 × 平均分段大小 × 3

示例:
- 528 个分段
- 每个分段 6MB (视频) + 200KB (音频)
- 所需: 528 × 6.2MB × 3 ≈ 10GB
```

`× 3` 是因为需要：
1. 原始分段
2. 合并后的文件
3. 最终 MP4

## 🎨 自定义配置

### 下载不同画质

如果服务器提供多种画质：

```bash
# 720p
VIDEO_URL_TEMPLATE="https://...../720p_{NUM}.cmfv"

# 1080p
VIDEO_URL_TEMPLATE="https://...../1080p_{NUM}.cmfv"

# 4K
VIDEO_URL_TEMPLATE="https://...../2160p_{NUM}.cmfv"
```

### 下载不同语言

```bash
# 英语
AUDIO_URL_TEMPLATE="https://...../ENG_1_{NUM}.cmfa"
VTT_URL_TEMPLATE="https://...../en-US_{NUM}.vtt"

# 中文
AUDIO_URL_TEMPLATE="https://...../ZHO_1_{NUM}.cmfa"
VTT_URL_TEMPLATE="https://...../zh-CN_{NUM}.vtt"
```

### 只下载部分片段

```bash
# 只下载前 10 分钟（假设每分钟 6 个分段）
START_SEGMENT=1
END_SEGMENT=60
```

## 📝 脚本工作原理

### 1. Init Segment

CMAF 格式的视频需要一个初始化文件：

```bash
# 视频 init 包含：
- 编解码器信息（H.264, HEVC 等）
- 分辨率
- 帧率
- 等元数据

# 音频 init 包含：
- 音频编码（AAC, MP3 等）
- 采样率
- 声道数
```

### 2. 分段编号

使用补零确保正确排序：

```
错误: 1, 2, 3, ..., 10, 11, 100, 101  # 字符串排序会乱
正确: 000000001, 000000002, ..., 000000100  # 正确排序
```

### 3. 二进制拼接

CMAF 分段可以直接二进制拼接：

```bash
cat init.cmfv seg_1.cmfv seg_2.cmfv > merged.cmfv
```

### 4. FFmpeg 混流

最后使用 FFmpeg 将视频、音频、字幕合并：

```bash
ffmpeg -i video.cmfv -i audio.cmfa -i subtitle.vtt \
  -c:v copy -c:a copy -c:s mov_text output.mp4
```

## 🔍 调试技巧

### 查看下载列表

```bash
cat segments/video_urls.txt | head
cat segments/audio_urls.txt | head
```

### 检查已下载分段

```bash
# 统计数量
ls segments/video/*.cmfv | wc -l
ls segments/audio/*.cmfa | wc -l

# 查看大小
du -sh segments/video
du -sh segments/audio
```

### 手动下载单个分段

```bash
curl -o test.cmfv "https://...../1080p_000000001.cmfv"
```

### 手动拼接测试

```bash
cat segments/video/init.cmfv \
    segments/video/seg_000000001.cmfv \
    segments/video/seg_000000002.cmfv \
    > test_merged.cmfv

# 用 ffplay 测试播放
ffplay test_merged.cmfv
```

## 💡 最佳实践

1. **先测试小范围**
   ```bash
   END_SEGMENT=10  # 先下载 10 个分段测试
   ```

2. **保留临时文件**（第一次运行时）
   ```
   删除临时文件? (y/n)
   n  # 第一次选择 n，确认没问题再删除
   ```

3. **使用合理的并发数**
   ```bash
   CONCURRENT_JOBS=10  # 不要过高，避免被限流
   ```

4. **定期检查进度**
   ```bash
   # 另开一个终端
   watch -n 5 'ls segments/video/*.cmfv | wc -l'
   ```

---

有问题？查看 `README.md` 或重新配置脚本。
