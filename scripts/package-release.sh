#!/bin/bash
# 从指定提交独立构建并打包未公证的 DMG，开发配置与已安装 App 不参与替换。
set -euo pipefail

fail() { printf '打包失败：%s\n' "$*" >&2; exit 1; }

[[ $# -le 1 ]] || fail '用法：./scripts/package-release.sh [Git 提交或引用，默认 HEAD]'
repo_root=$(cd "$(dirname "$0")/.." && pwd -P)
commit=$(git -C "$repo_root" rev-parse --verify --end-of-options "${1:-HEAD}^{commit}") || fail '无法解析指定的 Git 提交。'
output_root="$repo_root/build/Releases"
[[ ! -L "$repo_root/build" && ! -L "$output_root" ]] || fail '拒绝将发行产物写入符号链接目录。'
git -C "$repo_root" check-ignore -q "$output_root/" || fail '发行输出目录必须被 Git 忽略。'
mkdir -p "$output_root"
run_dir=$(mktemp -d "$output_root/$(date +%Y%m%d-%H%M%S)-${commit:0:12}.XXXXXX")
# 保留进度输出，完整命令输出写文件；不依赖 /dev/fd 的进程替换。
exec 3>&1
exec > "$run_dir/package.log" 2>&1
log() { printf "$@"; printf "$@" >&3; }

source_dir="$run_dir/Source"
staging_dir="$run_dir/Staging"
mount_dir="$run_dir/Mounted"
image_attached=false
step=导出源码

finish() {
    local result=$?
    trap - EXIT
    trap '' INT TERM HUP
    if [[ "$image_attached" == true ]] && /sbin/mount | grep -Fq " on $mount_dir ("; then
        if ! hdiutil detach "$mount_dir" >> "$run_dir/dmg.log" 2>&1; then
            printf '无法卸载验证映像，请手动处理：%s\n' "$mount_dir" >&2
            result=1
        fi
    fi
    if [[ "$result" != 0 ]]; then
        log '打包在“%s”阶段停止，现场和日志全部保留：%s\n' "$step" "$run_dir"
    fi
    exit "$result"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

log '源码提交：%s\n产物目录：%s\n' "$commit" "$run_dir"
printf '%s\n' "$commit" > "$run_dir/BUILD_COMMIT.txt"
mkdir -p "$source_dir" "$staging_dir" "$mount_dir"
git -C "$repo_root" archive --format=tar "$commit" | tar -xf - -C "$source_dir"
[[ -f "$source_dir/LICENSE" ]] || fail '指定提交缺少 LICENSE，请先提交许可证。'
[[ -f "$source_dir/Ordo.xcodeproj/xcshareddata/xcschemes/Ordo.xcscheme" ]] || fail '指定提交缺少共享 Ordo scheme。'
project="$source_dir/Ordo.xcodeproj/project.pbxproj"
settings=objects.I00000000000000000000012.buildSettings
bundle_id=$(plutil -extract "$settings.PRODUCT_BUNDLE_IDENTIFIER" raw -- "$project")
version=$(plutil -extract "$settings.MARKETING_VERSION" raw -- "$project")
build_number=$(plutil -extract "$settings.CURRENT_PROJECT_VERSION" raw -- "$project")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$build_number" =~ ^[0-9]+$ ]] || fail '版本必须为三段数字，构建号必须为整数。'

step=独立构建
log '正在构建 Ordo %s（%s），架构 arm64 与 x86_64…\n' "$version" "$build_number"
xcodebuild -version > "$run_dir/toolchain.txt"
if ! xcodebuild -project "$source_dir/Ordo.xcodeproj" -scheme Ordo \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$run_dir/DerivedData" \
    CONFIGURATION_BUILD_DIR="$run_dir/Products" \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO \
    build > "$run_dir/build.log" 2>&1; then
    tail -n 60 "$run_dir/build.log"
    fail "构建未通过，完整日志：$run_dir/build.log"
fi

step=签名与验证
app="$staging_dir/Ordo.app"
ditto "$run_dir/Products/Ordo.app" "$app"
# 移除包含源码与中间产物绝对路径的调试索引，仅处理分发副本。
xcrun strip -S "$app/Contents/MacOS/Ordo"
codesign --force --sign - --options runtime --timestamp=none "$app"

verify_app() {
    local candidate="$1" label="$2" plist="$1/Contents/Info.plist"
    local key expected actual arch signing_file entitlements_file
    codesign --verify --deep --strict --all-architectures "$candidate"
    actual=$(lipo -archs "$candidate/Contents/MacOS/Ordo")
    [[ "$actual" == 'x86_64 arm64' || "$actual" == 'arm64 x86_64' ]] || fail "产物不是预期的 Universal 2：$actual"
    if LC_ALL=C grep -a -Eq '/Users/|/private/var/folders/' "$candidate/Contents/MacOS/Ordo"; then
        fail "$label 的可执行文件仍包含本机用户或临时目录路径。"
    fi
    while IFS='=' read -r key expected; do
        actual=$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist")
        [[ "$actual" == "$expected" ]] || fail "$label 的 $key 不符：$actual"
    done <<EOF
CFBundleIdentifier=$bundle_id
CFBundleExecutable=Ordo
CFBundleShortVersionString=$version
CFBundleVersion=$build_number
LSMinimumSystemVersion=14.0
LSUIElement=true
EOF
    for arch in arm64 x86_64; do
        signing_file="$run_dir/$label-$arch-signature.txt"
        entitlements_file="$run_dir/$label-$arch-entitlements.plist"
        codesign -d --arch "$arch" --verbose=4 "$candidate" 2> "$signing_file"
        grep -Fxq 'Signature=adhoc' "$signing_file" || fail "$label 的 $arch 不是 ad-hoc 签名。"
        grep -Fxq 'TeamIdentifier=not set' "$signing_file" || fail "$label 的 $arch 仍含开发团队身份。"
        grep -Eq '^CodeDirectory .*flags=.*runtime' "$signing_file" || fail "$label 的 $arch 未启用 Hardened Runtime。"
        if grep -q '^Authority=' "$signing_file"; then
            fail "$label 的 $arch 仍含个人签名证书。"
        fi
        codesign -d --arch "$arch" --entitlements - "$candidate" > "$entitlements_file" 2>> "$signing_file"
        if [[ -s "$entitlements_file" ]]; then
            plutil -lint "$entitlements_file"
            for key in com.apple.security.app-sandbox com.apple.security.get-task-allow get-task-allow; do
                if /usr/libexec/PlistBuddy -c "Print :$key" "$entitlements_file" >/dev/null 2>&1; then
                    fail "$label 的 $arch 包含禁止的 entitlement：$key"
                fi
            done
        fi
    done
}
verify_app "$app" staging

step=创建安装映像
ln -s /Applications "$staging_dir/Applications"
cp "$source_dir/LICENSE" "$staging_dir/LICENSE"
dmg_name="Ordo-$version-universal.dmg"
dmg="$run_dir/$dmg_name"
hdiutil create -fs HFS+ -format UDZO -volname Ordo -srcfolder "$staging_dir" "$dmg" > "$run_dir/dmg.log" 2>&1
hdiutil verify "$dmg" >> "$run_dir/dmg.log" 2>&1

step=验证安装映像
# 先登记尝试状态，覆盖映像已挂载但 attach 尚未返回时收到中断的边界。
image_attached=true
hdiutil attach -readonly -nobrowse -mountpoint "$mount_dir" "$dmg" >> "$run_dir/dmg.log" 2>&1
verify_app "$mount_dir/Ordo.app" mounted
[[ -L "$mount_dir/Applications" && "$(readlink "$mount_dir/Applications")" == /Applications ]] || fail 'DMG 缺少正确的 Applications 入口。'
cmp "$source_dir/LICENSE" "$mount_dir/LICENSE" || fail 'DMG 中的 LICENSE 与源码不一致。'
hdiutil detach "$mount_dir" >> "$run_dir/dmg.log" 2>&1
image_attached=false

step=记录校验值
(cd "$run_dir" && shasum -a 256 "$dmg_name" > SHA256SUMS.txt)
log '打包完成：%s\n校验文件：%s\n提交记录：%s\n' "$dmg" "$run_dir/SHA256SUMS.txt" "$run_dir/BUILD_COMMIT.txt"
log '这是未公证的 ad-hoc 版本，首次下载启动需要按 macOS 的安全提示操作。\n'
