#!/usr/bin/env bash
# Shell authon: JackA1ltman <cs2dtzq@163.com>
# 20250918

echo "Starting check .rej files..."

# 检查是否存在.rej文件
if ! find . -name "*.rej" -type f | head -1 > /dev/null 2>&1; then
    echo "Current folder not found .rej"
    exit 0
fi

# 显示找到的文件
echo "Found .rej files:"
find . -name "*.rej" -type f
echo "----------------------------------------"

temp_dir=$(mktemp -d)
echo "Create tmp folder: $temp_dir"

# 计数器
rej_count=0
original_count=0
missing_count=0

find . -name "*.rej" -type f -print0 | while IFS= read -r -d '' rej_file; do
    ((rej_count++))
    echo "Processing of the $rej_count file: $rej_file"

    original_file="${rej_file%.rej}"

    temp_rej_path="$temp_dir/$rej_file"
    temp_orig_path="$temp_dir/$original_file"

    mkdir -p "$(dirname "$temp_rej_path")"

    if cp "$rej_file" "$temp_rej_path"; then
        echo "  ✓ Copied: $rej_file"
    else
        echo "  ✗ Copy failed: $rej_file"
        continue
    fi

    if [[ -f "$original_file" ]]; then
        mkdir -p "$(dirname "$temp_orig_path")"
        if cp "$original_file" "$temp_orig_path"; then
            echo "  ✓ 已复制: $original_file"
            ((original_count++))
        else
            echo "  ✗ 复制原始文件失败: $original_file"
        fi
    else
        echo "  ! 原始文件不存在: $original_file"
        ((missing_count++))
    fi

    echo "$rej_count" > "$temp_dir/.rej_count"
    echo "$original_count" > "$temp_dir/.original_count"
    echo "$missing_count" > "$temp_dir/.missing_count"
done

if [[ -f "$temp_dir/.rej_count" ]]; then
    rej_count=$(cat "$temp_dir/.rej_count")
    original_count=$(cat "$temp_dir/.original_count")
    missing_count=$(cat "$temp_dir/.missing_count")

    rm $temp_dir/.rej_count
    rm $temp_dir/.original_count
    rm $temp_dir/.missing_count
fi

echo "----------------------------------------"
echo "Files:"
echo "  .rej files count: $rej_count"
echo "  Origin files: $original_count"
echo "  Missing origin files: $missing_count"

if [[ ! -d "$temp_dir" ]] || [[ -z "$(find "$temp_dir" -name "*.rej" 2>/dev/null)" ]]; then
    echo "Error: have no any files to tmp folder"
    rm -rf "$temp_dir"
    exit 1
fi

archive_name="rej_files.tar.gz"

echo "Create null archive: $archive_name"

# 创建压缩包
if tar -czf "$archive_name" -C "$temp_dir" .; then
    echo "✓ Create archive successfully: $archive_name"

    archive_size=$(du -h "$archive_name" | cut -f1)
    echo "Archive size: $archive_size"

    echo "Archive content:"
    tar -tzf "$archive_name" | head -20
    if [[ $(tar -tzf "$archive_name" | wc -l) -gt 20 ]]; then
        echo "... (共 $(tar -tzf "$archive_name" | wc -l) 个文件)"
    fi

else
    echo "✗ Create archive failed : $archive_name"
    rm -rf "$temp_dir"
    exit 1
fi

# 清理临时目录
echo "Cleaning tmp folder: $temp_dir"
rm -rf "$temp_dir"

echo "✓ Successfully！"
echo "Archive name: $PWD/$archive_name"
