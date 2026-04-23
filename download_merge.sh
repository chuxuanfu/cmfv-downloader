#!/bin/zsh
# CMFV/CMFA 下载器 - 可靠版本
# 串行下载 + 文件验证 + 自动重试

set -e

# ╔══════════════════════════════════════════════════════════════╗
# ║  ⬇⬇⬇  只需要修改这个区域  ⬇⬇⬇                              ║
# ╚══════════════════════════════════════════════════════════════╝

# ---------- 分段范围 ----------
START_SEGMENT=1          # 起始编号
END_SEGMENT=528          # 结束编号
NUM_DIGITS=9             # 编号位数 (例如 9 → 000000001)

# ---------- Init Segment URL ----------
INIT_VIDEO_URL="https://fc-cdn-int.apple.com/applevideo/d169b6c0/d169b6c0_1776809163_1080p/1080pinit.cmfv"
INIT_AUDIO_URL="https://fc-cdn-int.apple.com/applevideo/d169b6c0/d169b6c0_1776809163_audio_1/ENG_1init.cmfa"

# ---------- 分段 URL 模板 ----------
# 用 {NUM} 作为占位符，会被替换为补零后的编号
VIDEO_URL_TEMPLATE="https://fc-cdn-int.apple.com/applevideo/d169b6c0/d169b6c0_1776809163_1080p/1080p_{NUM}.cmfv"
AUDIO_URL_TEMPLATE="https://fc-cdn-int.apple.com/applevideo/d169b6c0/d169b6c0_1776809163_audio_1/ENG_1_{NUM}.cmfa"
# ---------- 下载设置 ----------
MIN_VIDEO_SIZE=100000    # 视频分段最小 100KB
MIN_AUDIO_SIZE=10000     # 音频分段最小 10KB
OUTPUT_NAME="final_video" # 输出文件名 (不含扩展名)

# ╔══════════════════════════════════════════════════════════════╗
# ║  ⬆⬆⬆  配置结束，以下不需要修改  ⬆⬆⬆                        ║
# ╚══════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/segments"
FINAL_OUTPUT="$SCRIPT_DIR/${OUTPUT_NAME}.mp4"
TOTAL_SEGMENTS=$((END_SEGMENT - START_SEGMENT + 1))

mkdir -p "$OUTPUT_DIR"/{video,audio}

# ============================================================
#  下载并验证函数
# ============================================================
download_with_validation() {
    local url="$1"
    local output="$2"
    local min_size=$3
    local max_retries=5
    
    for ((retry=1; retry<=max_retries; retry++)); do
        if curl -sS -f -m 30 -o "$output" "$url" 2>/dev/null; then
            if [[ -f "$output" ]]; then
                local size=$(stat -f%z "$output" 2>/dev/null || echo 0)
                if [[ $size -ge $min_size ]]; then
                    return 0  # 成功
                else
                    # 文件太小，删除重试
                    rm -f "$output"
                    [[ $retry -lt $max_retries ]] && sleep 1
                fi
            fi
        else
            [[ $retry -lt $max_retries ]] && sleep 1
        fi
    done
    
    return 1  # 失败
}

# ============================================================
#  Step 0: Init Segments
# ============================================================
echo "╔════════════════════════════════════════════════╗"
echo "║  CMFV/CMFA 视频下载器 - 可靠版本               ║"
echo "║  串行下载 + 文件验证 + 自动重试                ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Step 0: 下载 Init Segment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -n "$INIT_VIDEO_URL" ]]; then
    if [[ ! -f "$OUTPUT_DIR/video/init.cmfv" ]] || [[ ! -s "$OUTPUT_DIR/video/init.cmfv" ]]; then
        if download_with_validation "$INIT_VIDEO_URL" "$OUTPUT_DIR/video/init.cmfv" 500; then
            echo "  ✅ Video init: $(du -h "$OUTPUT_DIR/video/init.cmfv" | cut -f1)"
        else
            echo "  ❌ Video init 下载失败"
            exit 1
        fi
    else
        echo "  ✅ Video init 已存在"
    fi
else
    echo "  ⏭️  未配置 Video init URL，跳过"
fi

if [[ -n "$INIT_AUDIO_URL" ]]; then
    if [[ ! -f "$OUTPUT_DIR/audio/init.cmfa" ]] || [[ ! -s "$OUTPUT_DIR/audio/init.cmfa" ]]; then
        if download_with_validation "$INIT_AUDIO_URL" "$OUTPUT_DIR/audio/init.cmfa" 500; then
            echo "  ✅ Audio init: $(du -h "$OUTPUT_DIR/audio/init.cmfa" | cut -f1)"
        else
            echo "  ❌ Audio init 下载失败"
            exit 1
        fi
    else
        echo "  ✅ Audio init 已存在"
    fi
else
    echo "  ⏭️  未配置 Audio init URL，跳过"
fi

echo ""

# ============================================================
#  Step 1: 下载视频分段
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📹 Step 1/3: 下载视频分段（带验证和重试）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -z "$VIDEO_URL_TEMPLATE" ]]; then
    echo "  ⏭️  未配置视频 URL，跳过"
    SKIP_VIDEO=true
else
    SKIP_VIDEO=false
    COUNT=0
    SUCCESS=0
    FAILED=0
    SKIPPED=0

    for i in $(seq $START_SEGMENT $END_SEGMENT); do
        NUM=$(printf "%0${NUM_DIGITS}d" $i)
        COUNT=$((COUNT + 1))
        PCT=$(( COUNT * 100 / TOTAL_SEGMENTS ))
        
        OUTPUT_FILE="$OUTPUT_DIR/video/seg_${NUM}.cmfv"
        
        # 检查是否已存在且有效
        if [[ -f "$OUTPUT_FILE" ]]; then
            SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || echo 0)
            if [[ $SIZE -ge $MIN_VIDEO_SIZE ]]; then
                SKIPPED=$((SKIPPED + 1))
                printf "\r  [%3d%%] %d/%d (成功:%d 跳过:%d 失败:%d)" \
                    $PCT $COUNT $TOTAL_SEGMENTS $SUCCESS $SKIPPED $FAILED
                continue
            fi
        fi
        
        printf "\r  [%3d%%] %d/%d (成功:%d 跳过:%d 失败:%d)" \
            $PCT $COUNT $TOTAL_SEGMENTS $SUCCESS $SKIPPED $FAILED
        
        URL="${VIDEO_URL_TEMPLATE/\{NUM\}/$NUM}"
        
        if download_with_validation "$URL" "$OUTPUT_FILE" $MIN_VIDEO_SIZE; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
            printf "\n  ⚠️  第 %d 个分段失败: seg_%s.cmfv\n" $COUNT $NUM
        fi
        
        # 每10个显示详细信息
        if (( COUNT % 10 == 0 )); then
            SIZE=$(du -sh "$OUTPUT_DIR/video" 2>/dev/null | cut -f1)
            printf "\r  [%3d%%] %d/%d - 已下载: %s (成功:%d 跳过:%d 失败:%d)\n" \
                $PCT $COUNT $TOTAL_SEGMENTS $SIZE $SUCCESS $SKIPPED $FAILED
        fi
        
        # 避免请求过快
        sleep 0.1
    done

    echo ""
    echo ""
    TOTAL_VIDEO_OK=$((SUCCESS + SKIPPED))
    echo "  📊 视频下载统计："
    echo "     成功: $SUCCESS 个"
    echo "     跳过: $SKIPPED 个（已存在）"
    echo "     失败: $FAILED 个"
    echo "     总计: $TOTAL_VIDEO_OK / $TOTAL_SEGMENTS"
    
    if [[ $FAILED -gt 10 ]]; then
        echo ""
        echo "  ❌ 失败太多（$FAILED 个），建议："
        echo "     1. 检查网络连接"
        echo "     2. 重新运行脚本（会自动跳过已下载的）"
        exit 1
    elif [[ $FAILED -gt 0 ]]; then
        echo "  ⚠️  有 $FAILED 个分段失败，将在拼接时跳过"
    fi
fi

echo ""

# ============================================================
#  Step 2: 下载音频分段
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔊 Step 2/3: 下载音频分段"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -z "$AUDIO_URL_TEMPLATE" ]]; then
    echo "  ⏭️  未配置音频 URL，跳过"
    SKIP_AUDIO=true
else
    SKIP_AUDIO=false
    COUNT=0
    SUCCESS=0
    FAILED=0
    SKIPPED=0

    for i in $(seq $START_SEGMENT $END_SEGMENT); do
        NUM=$(printf "%0${NUM_DIGITS}d" $i)
        COUNT=$((COUNT + 1))
        PCT=$(( COUNT * 100 / TOTAL_SEGMENTS ))
        
        OUTPUT_FILE="$OUTPUT_DIR/audio/seg_${NUM}.cmfa"
        
        if [[ -f "$OUTPUT_FILE" ]]; then
            SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || echo 0)
            if [[ $SIZE -ge $MIN_AUDIO_SIZE ]]; then
                SKIPPED=$((SKIPPED + 1))
                printf "\r  [%3d%%] %d/%d" $PCT $COUNT $TOTAL_SEGMENTS
                continue
            fi
        fi
        
        printf "\r  [%3d%%] %d/%d" $PCT $COUNT $TOTAL_SEGMENTS
        
        URL="${AUDIO_URL_TEMPLATE/\{NUM\}/$NUM}"
        
        if download_with_validation "$URL" "$OUTPUT_FILE" $MIN_AUDIO_SIZE; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
        fi
        
        if (( COUNT % 10 == 0 )); then
            SIZE=$(du -sh "$OUTPUT_DIR/audio" 2>/dev/null | cut -f1)
            printf "\r  [%3d%%] %d/%d - 已下载: %s\n" $PCT $COUNT $TOTAL_SEGMENTS $SIZE
        fi
        
        sleep 0.1
    done

    echo ""
    echo ""
    echo "  📊 音频下载统计："
    echo "     成功: $SUCCESS 个"
    echo "     跳过: $SKIPPED 个"
    echo "     失败: $FAILED 个"
fi

echo ""

# ============================================================
#  Step 3: 拼接和混流
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 Step 3/3: 拼接分段并混流"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# cat 合并视频分段（比 ffmpeg concat demuxer 快数十倍）
COMBINED_VIDEO="$OUTPUT_DIR/combined.cmfv"
COMBINED_AUDIO="$OUTPUT_DIR/combined.cmfa"

if [[ $SKIP_VIDEO == false ]]; then
    echo "  📹 合并视频分段（cat）..."
    CONCAT_COUNT=0
    MISSING_COUNT=0
    # 收集要合并的文件
    VIDEO_FILES=()
    [[ -f "$OUTPUT_DIR/video/init.cmfv" && -s "$OUTPUT_DIR/video/init.cmfv" ]] && \
        VIDEO_FILES+=("$OUTPUT_DIR/video/init.cmfv")
    for i in $(seq $START_SEGMENT $END_SEGMENT); do
        NUM=$(printf "%0${NUM_DIGITS}d" $i)
        F="$OUTPUT_DIR/video/seg_${NUM}.cmfv"
        if [[ -f "$F" ]]; then
            SIZE=$(stat -f%z "$F" 2>/dev/null || echo 0)
            if [[ $SIZE -ge $MIN_VIDEO_SIZE ]]; then
                VIDEO_FILES+=("$F")
                CONCAT_COUNT=$((CONCAT_COUNT + 1))
            else
                MISSING_COUNT=$((MISSING_COUNT + 1))
            fi
        else
            MISSING_COUNT=$((MISSING_COUNT + 1))
        fi
    done
    echo "     共 $CONCAT_COUNT 个视频分段"
    [[ $MISSING_COUNT -gt 0 ]] && echo "     ⚠️  跳过了 $MISSING_COUNT 个缺失/损坏的分段"
    echo -n "     正在 cat 合并..."
    cat "${VIDEO_FILES[@]}" > "$COMBINED_VIDEO"
    echo " 完成 ($(du -h "$COMBINED_VIDEO" | cut -f1))"
fi

if [[ $SKIP_AUDIO == false ]]; then
    echo "  🔊 合并音频分段（cat）..."
    CONCAT_COUNT=0
    AUDIO_FILES=()
    [[ -f "$OUTPUT_DIR/audio/init.cmfa" && -s "$OUTPUT_DIR/audio/init.cmfa" ]] && \
        AUDIO_FILES+=("$OUTPUT_DIR/audio/init.cmfa")
    for i in $(seq $START_SEGMENT $END_SEGMENT); do
        NUM=$(printf "%0${NUM_DIGITS}d" $i)
        F="$OUTPUT_DIR/audio/seg_${NUM}.cmfa"
        if [[ -f "$F" ]]; then
            SIZE=$(stat -f%z "$F" 2>/dev/null || echo 0)
            if [[ $SIZE -ge $MIN_AUDIO_SIZE ]]; then
                AUDIO_FILES+=("$F")
                CONCAT_COUNT=$((CONCAT_COUNT + 1))
            fi
        fi
    done
    echo "     共 $CONCAT_COUNT 个音频分段"
    echo -n "     正在 cat 合并..."
    cat "${AUDIO_FILES[@]}" > "$COMBINED_AUDIO"
    echo " 完成 ($(du -h "$COMBINED_AUDIO" | cut -f1))"
fi

# ffmpeg 混流（只需处理 2 个文件）
echo ""
echo "  🎬 使用 ffmpeg 混流..."

if ! command -v ffmpeg &> /dev/null; then
    echo "  ❌ 需要 ffmpeg: brew install ffmpeg"
    exit 1
fi

FFMPEG_CMD=(ffmpeg -y -hide_banner -loglevel warning -stats)

INPUT_COUNT=0
if [[ $SKIP_VIDEO == false && -f "$COMBINED_VIDEO" ]]; then
    FFMPEG_CMD+=(-i "$COMBINED_VIDEO")
    VIDEO_IDX=$INPUT_COUNT
    INPUT_COUNT=$((INPUT_COUNT + 1))
fi
if [[ $SKIP_AUDIO == false && -f "$COMBINED_AUDIO" ]]; then
    FFMPEG_CMD+=(-i "$COMBINED_AUDIO")
    AUDIO_IDX=$INPUT_COUNT
    INPUT_COUNT=$((INPUT_COUNT + 1))
fi

[[ -n "$VIDEO_IDX" ]] && FFMPEG_CMD+=(-map "${VIDEO_IDX}:v")
[[ -n "$AUDIO_IDX" ]] && FFMPEG_CMD+=(-map "${AUDIO_IDX}:a")

FFMPEG_CMD+=(-c:v copy -c:a copy)
FFMPEG_CMD+=(-movflags +faststart)
FFMPEG_CMD+=("$FINAL_OUTPUT")

if "${FFMPEG_CMD[@]}"; then
    echo "  ✅ 混流成功"
    # 清理临时合并文件
    rm -f "$COMBINED_VIDEO" "$COMBINED_AUDIO"
else
    echo "  ❌ 混流失败"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "╔════════════════════════════════════════════════╗"
echo "║  ✅ 下载完成！                                 ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "📁 输出文件: $FINAL_OUTPUT"
echo "📦 文件大小: $(du -h "$FINAL_OUTPUT" | cut -f1)"
echo ""

# ============================================================
#  验证视频完整性
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 验证视频完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ $SKIP_VIDEO == false ]]; then
    V_DUR=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$FINAL_OUTPUT" 2>/dev/null || echo "0")
    V_MIN=$(printf "%.1f" $(echo "$V_DUR / 60" | bc -l 2>/dev/null || echo "0"))
    echo "  视频流: ${V_MIN} 分钟"
fi

if [[ $SKIP_AUDIO == false ]]; then
    A_DUR=$(ffprobe -v error -select_streams a:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$FINAL_OUTPUT" 2>/dev/null || echo "0")
    A_MIN=$(printf "%.1f" $(echo "$A_DUR / 60" | bc -l 2>/dev/null || echo "0"))
    echo "  音频流: ${A_MIN} 分钟"
fi

TOTAL_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FINAL_OUTPUT" 2>/dev/null || echo "0")
TOTAL_MIN=$(printf "%.1f" $(echo "$TOTAL_DUR / 60" | bc -l 2>/dev/null || echo "0"))
echo "  总时长: ${TOTAL_MIN} 分钟"

echo ""

# 检查视频和总时长是否匹配
if [[ $SKIP_VIDEO == false && -n "$V_DUR" && -n "$TOTAL_DUR" ]]; then
    DIFF=$(echo "$TOTAL_DUR - $V_DUR" | bc | tr -d '-')
    DIFF_INT=$(printf "%.0f" $DIFF)
    
    if (( DIFF_INT < 5 )); then
        echo "╔════════════════════════════════════════════════╗"
        echo "║  ✅✅✅ 成功！视频完整，可以正常播放！         ║"
        echo "╚════════════════════════════════════════════════╝"
    else
        echo "⚠️  警告：视频流时长和总时长差异 ${DIFF_INT} 秒"
        echo "   可能在 ${V_MIN} 分钟后出现黑屏"
        echo ""
        echo "建议："
        echo "  1. 重新运行脚本补充下载"
        echo "  2. 检查失败的分段"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "删除临时文件? (y/n)"
read -r CLEANUP
[[ "$CLEANUP" == "y" ]] && rm -rf "$OUTPUT_DIR" && echo "  🧹 已清理"

echo ""
echo "完成！可以播放 $FINAL_OUTPUT 验证效果。"
