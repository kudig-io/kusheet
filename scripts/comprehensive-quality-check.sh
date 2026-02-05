#!/bin/bash

# Kubernetes知识库全面质量检查脚本
# 检查文档完整性、链接有效性、内容质量等

echo "=== Kubernetes知识库全面质量检查 ==="
echo "检查时间: $(date)"
echo

# 1. 检查目录结构完整性
echo "1. 检查目录结构完整性..."
DOMAINS=(domain-1-architecture-fundamentals domain-2-design-principles domain-3-control-plane domain-4-workloads domain-5-networking domain-6-storage domain-7-security domain-8-observability domain-9-platform-ops domain-10-extensions domain-11-ai-infra domain-12-troubleshooting domain-13-docker domain-14-linux domain-15-network-fundamentals domain-16-storage-fundamentals domain-17-cloud-provider)

MISSING_DOMAINS=()
for domain in "${DOMAINS[@]}"; do
    if [ ! -d "$domain" ]; then
        MISSING_DOMAINS+=("$domain")
    fi
done

if [ ${#MISSING_DOMAINS[@]} -eq 0 ]; then
    echo "✅ 所有核心domain目录存在"
else
    echo "❌ 缺失的domain目录: ${MISSING_DOMAINS[*]}"
fi

# 2. 检查topic目录完整性
echo
echo "2. 检查topic目录完整性..."
TOPIC_DIRS=(topic-dictionary topic-presentations topic-trouble-shooting)

for topic in "${TOPIC_DIRS[@]}"; do
    if [ -d "$topic" ]; then
        echo "✅ $topic 目录存在"
        FILES_COUNT=$(find "$topic" -name "*.md" | wc -l)
        echo "   包含 $FILES_COUNT 个Markdown文件"
    else
        echo "❌ $topic 目录缺失"
    fi
done

# 3. 检查README引用的文档是否存在
echo
echo "3. 检查README中引用的文档链接..."
MISSING_LINKS=()

# 提取README中的所有相对链接
LINKS=$(grep -o '\.\/domain-[0-9]*[^)]*' README.md | sort | uniq)

for link in $LINKS; do
    # 移除开头的./
    CLEAN_LINK="${link#\./}"
    if [ ! -f "$CLEAN_LINK" ]; then
        MISSING_LINKS+=("$link")
    fi
done

if [ ${#MISSING_LINKS[@]} -eq 0 ]; then
    echo "✅ README中所有文档链接都有效"
else
    echo "❌ README中缺失的文档链接:"
    for missing in "${MISSING_LINKS[@]}"; do
        echo "   $missing"
    done
fi

# 4. 检查文档质量标准
echo
echo "4. 检查文档基本质量标准..."

# 检查文档长度（过短的文档可能需要增强）
SHORT_DOCS=()
find . -name "*.md" -not -path "./scripts/*" | while read file; do
    LINE_COUNT=$(wc -l < "$file")
    if [ $LINE_COUNT -lt 50 ] && [ "$file" != "./README.md" ]; then
        echo "⚠️  文档较短 ($LINE_COUNT行): $file"
    fi
done

# 5. 检查文档头部信息完整性
echo
echo "5. 检查文档头部信息完整性..."
INCOMPLETE_HEADERS=()

find . -name "*.md" -not -path "./scripts/*" | while read file; do
    # 检查是否有适用版本信息
    if ! grep -q "适用版本" "$file" && ! grep -q "Version" "$file" && [ "$file" != "./README.md" ]; then
        echo "⚠️  缺少版本信息: $file"
    fi
done

# 6. 检查专家级内容标识
echo
echo "6. 检查专家级内容标识..."

EXPERT_DOCS=()
find . -name "*.md" -not -path "./scripts/*" | while read file; do
    if grep -q "专家\|expert\|Enterprise\|生产环境" "$file"; then
        echo "✅ 包含专家级内容: $file"
    fi
done

# 7. 统计信息
echo
echo "7. 项目统计信息..."
TOTAL_DOCS=$(find . -name "*.md" -not -path "./scripts/*" | wc -l)
echo "总文档数量: $TOTAL_DOCS"

DOMAIN_DOCS=$(find domain-* -name "*.md" 2>/dev/null | wc -l)
echo "Domain文档数量: $DOMAIN_DOCS"

TOPIC_DOCS=$(find topic-* -name "*.md" 2>/dev/null | wc -l)
echo "Topic文档数量: $TOPIC_DOCS"

echo
echo "=== 质量检查完成 ==="