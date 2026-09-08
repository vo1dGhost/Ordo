#!/bin/bash
# 在独立目录完成构建与验签，再安全替换固定路径的本地 App。
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd -P)
build_root="$repo_root/build"
target_app="$build_root/Ordo.app"
lock_dir="$build_root/.dev-update.lock"
transaction_started=false
completed=false
initial_pids=-
run_dir=
archive_app=
helper=

fail() { printf '更新失败：%s\n' "$*" >&2; exit 1; }

[[ $# -eq 0 ]] || fail '此命令不接受参数；请直接运行 ./scripts/dev-update.sh。'
for path in "$build_root" "$build_root/Updates" "$build_root/Archive" "$target_app"; do
    [[ ! -L "$path" ]] || fail "拒绝操作符号链接：$path"
done
mkdir -p "$build_root"
mkdir "$lock_dir" 2>/dev/null || fail "已有更新或遗留锁：$lock_dir。确认没有更新进程后才可手动移除该空目录。"

rollback() {
    printf '更新未完成，正在检查能否恢复旧版。\n' >&2
    # 候选从原路径消失且目标存在，说明它已经安装；移动前必须再次确认退出。
    if [[ ! -e "$run_dir/Products/Ordo.app" && -e "$target_app" ]]; then
        local failed_pids
        failed_pids=$("$helper" check "$target_app") || return 1
        "$helper" stop "$target_app" "$failed_pids" || return 1
        mv "$target_app" "$run_dir/Failed-Ordo.app" || return 1
        printf '失败候选已保留：%s\n' "$run_dir/Failed-Ordo.app" >&2
    fi
    if [[ -e "$archive_app" ]]; then
        [[ ! -e "$target_app" ]] || return 1
        mv "$archive_app" "$target_app" || return 1
        printf '旧版已恢复：%s\n' "$target_app" >&2
    fi
    if [[ "$initial_pids" != - && -d "$target_app" ]]; then
        "$helper" launch "$target_app" "$initial_pids" || return 1
    fi
}

finish() {
    local result=$?
    trap - EXIT
    # 恢复期间先完成目录与进程收尾，避免重复中断提前释放锁。
    trap '' INT TERM HUP
    if [[ "$completed" == false && "$transaction_started" == true ]]; then
        result=1
        if ! rollback; then
            printf '无法安全自动恢复；保留当前 App 与旧版归档，请先检查运行状态。\n当前：%s\n旧版：%s\n候选：%s\n' \
                "$target_app" "$archive_app" "$run_dir" >&2
        fi
    fi
    rmdir "$lock_dir" || printf '未能释放更新锁：%s\n' "$lock_dir" >&2
    exit "$result"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

mkdir -p "$build_root/Updates" "$build_root/Archive"
run_dir=$(mktemp -d "$build_root/Updates/$(date +%Y%m%d-%H%M%S).XXXXXX")
archive_app="$build_root/Archive/$(basename "$run_dir")/Ordo.app"
helper="$run_dir/app-lifecycle"
printf '本次构建与日志目录：%s\n' "$run_dir"
xcrun swiftc -swift-version 6 -parse-as-library \
    -module-cache-path "$build_root/ModuleCache" \
    "$repo_root/scripts/AppLifecycle.swift" -o "$helper"
initial_pids=$("$helper" check "$target_app")

printf '正在构建稳定签名的 Release App…\n'
if ! xcodebuild -project "$repo_root/Ordo.xcodeproj" -scheme Ordo \
    -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$build_root/DerivedData" \
    CONFIGURATION_BUILD_DIR="$run_dir/Products" build > "$run_dir/build.log" 2>&1; then
    tail -n 60 "$run_dir/build.log" >&2
    fail "构建未通过，旧版未替换。需要团队 ND3SVRRF43 的有效 Apple Development 签名，不回退到临时签名。完整日志：$run_dir/build.log"
fi
candidate_app="$run_dir/Products/Ordo.app"
codesign --verify --deep --strict "$candidate_app"
"$helper" verify "$candidate_app"

# 长时间构建后重新枚举，避免退出中途打开的其他副本。
initial_pids=$("$helper" check "$target_app")
mkdir -p "$(dirname "$archive_app")"
"$helper" stop "$target_app" "$initial_pids"
transaction_started=true
if [[ -e "$target_app" ]]; then
    mv "$target_app" "$archive_app"
fi
mv "$candidate_app" "$target_app"
"$helper" launch "$target_app" "$initial_pids"
completed=true
printf '更新完成：%s\n' "$target_app"
if [[ -d "$archive_app" ]]; then
    printf '旧版归档：%s\n' "$archive_app"
fi
printf '首次切换签名可能需要重新授权一次；启动成功不代表辅助功能已获批。\n'
