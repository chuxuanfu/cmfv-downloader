#!/bin/zsh
# 快速拼接和混流工具

OUTPUT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEGMENTS_DIR="$OUTPUT_DIR/segments"
FINAL_OUTPUT="$OUTPUT_DIR/final_video.mp4"

echo "╔════════════════════════════════════════════════╗"
echo "║  快速拼接工具                                 ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# 检查分段目录
if [[ ! -d "$SEGMENTS_DIR/video" ]]; then
    echo "❌ 找不到 segments/video 目录"
    exit 1
fi

echo "📊 检查已下载的分段..."
V_COUNT=$(find "$SEGMENTS_DIR/video" -name "seg_*.cmfv" -size +100k | wc -l | tr -d ' ')
A_COUNT=$(find "$SEGMENTS_DIR/audio" -name "seg_*.cmfa" -size +10k | wc -l | tr -d ' ')
echo "  视频分段: $V_COUNT 个"
echo "  音频分段: $A_COUNT 个"
echo ""

# 使用 find 排序并直接拼接（避免大循环）
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📹 Step 1/3: 拼接视频分段"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MERGED_V="$SEGMENTS_DIR/merged_video.cmfv"

# 拼接视频：先写入 init，然后用 find 排序拼接
echo "  开始拼接视频..."
cat "$SEGMENTS_DIR/video/init.cmfv" > "$MERGED_V"

# 使用 find 找到所有分段并按数字排序
find "$SEGMENTS_DIR/video" -name "seg_*.cmfv" -size +100k | \
  sort -t_ -k2 -n | \
  while read -r seg_file; do
    cat "$seg_file" >> "$MERGED_V"
  done

SIZE=$(du -h "$MERGED_V" | cut -f1)
echo "  ✅ 视频拼接完成: $SIZE"
echo ""

# 拼接音频
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔊 Step 2/3: 拼接音频分段"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MERGED_A="$SEGMENTS_DIR/merged_audio.cmfa"

echo "  开始拼接音频..."
cat "$SEGMENTS_DIR/audio/init.cmfa" > "$MERGED_A"

find "$SEGMENTS_DIR/audio" -name "seg_*.cmfa" -size +10k | \
  sort -t_ -k2 -n | \
  while read -r seg_file; do
    cat "$seg_file" >> "$MERGED_A"
  done

SIZE=$(du -h "$MERGED_A" | cut -f1)
echo "  ✅ 音频拼接完成: $SIZE"
echo ""

# 验证拼接结果
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 验证拼接结果"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

V_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$MERGED_V" 2>/dev/null || echo "0")
A_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$MERGED_A" 2>/dev/null || echo "0")

V_MIN=$(printf "%.1f" $(echo "$V_DUR / 60" | bc -l))
A_MIN=$(printf "%.1f" $(echo "$A_DUR / 60" | bc -l))

echo "  视频时长: ${V_MIN} 分钟"
echo "  音频时长: ${A_MIN} 分钟"
echo ""

# 混流
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 Step 3/3: 混流生成 MP4"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  开始混流..."
ffmpeg -y -hide_banner -loglevel error -stats \
    -i "$MERGED_V" \
    -i "$MERGED_A" \
    -map 0:v -map 1:a \
    -c copy \
    -movflags +faststart \
    "$FINAL_OUTPUT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "╔════════════════════════════════════════════════╗"
echo "║  ✅ 完成！                                     ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "📁 输出文件: $FINAL_OUTPUT"
echo "📦 文件大小: $(du -h "$FINAL_OUTPUT" | cut -f1)"
echo ""

# 最终验证
FINAL_V_DUR=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$FINAL_OUTPUT" 2>/dev/null)
FINAL_A_DUR=$(ffprobe -v error -select_streams a:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$FINAL_OUTPUT" 2>/dev/null)
FINAL_TOTAL=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FINAL_OUTPUT" 2>/dev/null)

FINAL_V_MIN=$(printf "%.1f" $(echo "$FINAL_V_DUR / 60" | bc -l))
FINAL_TOTAL_MIN=$(printf "%.1f" $(echo "$FINAL_TOTAL / 60" | bc -l))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 最终验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  总时长:   ${FINAL_TOTAL_MIN} 分钟"
echo "  视频流:   ${FINAL_V_MIN} 分钟"
echo ""

DIFF=$(echo "$FINAL_TOTAL - $FINAL_V_DUR" | bc | tr -d '-')
DIFF_INT=$(printf "%.0f" $DIFF)

if (( DIFF_INT < 5 )); then
    echo "╔════════════════════════════════════════════════╗"
    echo "║  ✅✅✅ 成功！视频完整，可以正常播放！         ║"
    echo "╚════════════════════════════════════════════════╝"
else
    echo "⚠️  警告：视频流时长差异 ${DIFF_INT} 秒"
fi

echo ""
echo "可以播放验证: $FINAL_OUTPUT"
