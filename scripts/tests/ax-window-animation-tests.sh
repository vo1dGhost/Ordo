#!/bin/bash
# 将生产 AX 控制器与内存接口替身一起编译，验证动画边界，不操作真实窗口。
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd -P)
build_root="$repo_root/build"
test_root="$build_root/AXAnimationTests"
[[ ! -L "$build_root" && ! -L "$test_root" ]] || {
    printf '拒绝将测试产物写入符号链接目录。\n' >&2
    exit 1
}
mkdir -p "$test_root"
run_dir=$(mktemp -d "$test_root/$(date +%Y%m%d-%H%M%S).XXXXXX")
printf 'AX 动画测试产物保留在：%s\n' "$run_dir"

if ! xcrun clang -fobjc-arc -c "$repo_root/Ordo/System/SingleWindowActivationBridge.m" \
    -o "$run_dir/ActivationBridge.o" > "$run_dir/build.log" 2>&1; then
    tail -n 60 "$run_dir/build.log" >&2
    exit 1
fi
if ! xcrun swiftc -swift-version 6 -parse-as-library \
    -module-cache-path "$test_root/ModuleCache" \
    -import-objc-header "$repo_root/Ordo/System/Ordo-Bridging-Header.h" \
    "$repo_root"/Ordo/Core/*.swift \
    "$repo_root/Ordo/System/AXWindowController.swift" \
    "$repo_root/Ordo/System/AXWindowValidationReads.swift" \
    "$repo_root/Ordo/System/SingleWindowProcessActivator.swift" \
    "$repo_root/scripts/tests/AXWindowAnimationTests.swift" \
    "$run_dir/ActivationBridge.o" -o "$run_dir/ax-window-animation-tests" \
    >> "$run_dir/build.log" 2>&1; then
    tail -n 60 "$run_dir/build.log" >&2
    exit 1
fi
"$run_dir/ax-window-animation-tests" | tee "$run_dir/results.log"
