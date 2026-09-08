#!/bin/bash
set -euo pipefail

# 只操作 build/ 内自建的假 App，替换所有可能构建、签名或操作真实 App 的命令。
repo_root="$(cd "$(dirname "$0")/../.." && pwd -P)"
mkdir -p "$repo_root/build"
suite_root="$(mktemp -d "$repo_root/build/UpdaterTests.XXXXXX")"
stub_bin="$suite_root/bin"
mkdir -p "$stub_bin"
printf '测试产物保留在：%s\n' "$suite_root"

cat > "$stub_bin/xcodebuild" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'build\n' >> "$ORDO_TEST_ROOT/events"
if [[ "$ORDO_TEST_SCENARIO" == build_failure ]]; then
    exit 65
fi
if [[ "$ORDO_TEST_SCENARIO" == concurrent ]]; then
    touch "$ORDO_TEST_ROOT/build-waiting"
    for ((attempt = 0; attempt < 200; attempt++)); do
        [[ -f "$ORDO_TEST_ROOT/release-build" ]] && break
        sleep 0.05
    done
    [[ -f "$ORDO_TEST_ROOT/release-build" ]] || exit 66
fi
products=""
for argument in "$@"; do
    case "$argument" in
        CONFIGURATION_BUILD_DIR=*) products="${argument#*=}" ;;
    esac
done
[[ -n "$products" ]] || exit 67
mkdir -p "$products/Ordo.app/Contents/MacOS"
printf 'new\n' > "$products/Ordo.app/version"
printf '假 App，不可执行\n' > "$products/Ordo.app/Contents/MacOS/Ordo"
SH

cat > "$stub_bin/codesign" <<'SH'
#!/bin/bash
set -euo pipefail
printf 'codesign\n' >> "$ORDO_TEST_ROOT/events"
[[ "$ORDO_TEST_SCENARIO" != signature_failure ]]
SH

cat > "$stub_bin/xcrun" <<'SH'
#!/bin/bash
set -euo pipefail
[[ "$1" == swiftc ]] || exit 68
output=""
while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == -o ]]; then
        output="$2"
        break
    fi
    shift
done
[[ -n "$output" ]] || exit 69
cp "$ORDO_TEST_HELPER" "$output"
chmod +x "$output"
SH

cat > "$stub_bin/mv" <<'SH'
#!/bin/bash
set -euo pipefail
# 精确注入第二次替换失败，旧版归档和后续恢复仍使用系统 mv。
if [[ "$ORDO_TEST_SCENARIO" == replacement_failure && "$#" == 2 &&
      "$1" == */Products/Ordo.app && "$2" == "$ORDO_TEST_ROOT/build/Ordo.app" &&
      ! -f "$ORDO_TEST_ROOT/replacement-failed" ]]; then
    touch "$ORDO_TEST_ROOT/replacement-failed"
    exit 70
fi
exec /bin/mv "$@"
SH

cat > "$suite_root/app-lifecycle-stub" <<'SH'
#!/bin/bash
set -euo pipefail
command="$1"
target="$2"
version="missing"
[[ ! -f "$target/version" ]] || version="$(cat "$target/version")"
printf '%s %s\n' "$command" "$version" >> "$ORDO_TEST_ROOT/events"
case "$command" in
    verify)
        [[ "$ORDO_TEST_SCENARIO" != identity_failure ]]
        ;;
    check)
        if [[ "$ORDO_TEST_SCENARIO" == other_path ]]; then
            printf '发现其他路径的 Ordo：/其他路径/Ordo.app\n' >&2
            exit 71
        fi
        cat "$ORDO_TEST_ROOT/running"
        ;;
    stop)
        running="$(cat "$ORDO_TEST_ROOT/running")"
        [[ "$running" == - || ",$3," == *",$running,"* ]] || exit 75
        if [[ "$version" == old && "$ORDO_TEST_SCENARIO" == quit_timeout ]] ||
           [[ "$version" == new && "$ORDO_TEST_SCENARIO" == candidate_quit_failure ]]; then
            exit 72
        fi
        printf '%s\n' - > "$ORDO_TEST_ROOT/running"
        ;;
    launch)
        [[ "$(cat "$ORDO_TEST_ROOT/running")" == - ]] || exit 76
        if [[ "$version" == new ]]; then
            [[ ",$3," != *,222,* ]] || exit 77
            printf '222\n' > "$ORDO_TEST_ROOT/running"
            case "$ORDO_TEST_SCENARIO" in
                launch_failure|candidate_quit_failure|initially_stopped) exit 73 ;;
            esac
            printf '222\n'
        else
            printf '333\n' > "$ORDO_TEST_ROOT/running"
            printf '333\n'
        fi
        ;;
    *) exit 74 ;;
esac
SH
chmod +x "$stub_bin/"* "$suite_root/app-lifecycle-stub"

fail() {
    printf '失败：%s；现场：%s\n' "$*" "$case_root" >&2
    cat "$case_root/output.log" >&2
    exit 1
}

assert_file() {
    [[ -f "$1" ]] || fail "文件不存在：$1"
}

assert_content() {
    assert_file "$1"
    [[ "$(cat "$1")" == "$2" ]] || fail "内容不符：$1，应为 $2"
}

assert_event() {
    /usr/bin/grep -Fxq "$1" "$case_root/events" || fail "缺少事件：$1"
}

assert_no_event() {
    if /usr/bin/grep -Eq "$1" "$case_root/events"; then
        fail "不应发生事件：$1"
    fi
}

assert_archived() {
    local archive
    archive=("$case_root/build/Archive/"*/Ordo.app/version)
    [[ "${#archive[@]}" -eq 1 ]] || fail '归档数量不符'
    assert_content "${archive[0]}" old
}

assert_failed_candidate() {
    local candidate
    candidate=("$case_root/build/Updates/"*/Failed-Ordo.app/version)
    [[ "${#candidate[@]}" -eq 1 ]] || fail '失败候选数量不符'
    assert_content "${candidate[0]}" new
}

assert_untouched() {
    assert_content "$case_root/build/Ordo.app/version" old
    assert_content "$case_root/running" 111
    assert_no_event '^(stop|launch) '
}

prepare_case() {
    scenario="$1"
    # 路径包含空格，以覆盖脚本的路径引用。
    case_root="$suite_root/$scenario/repo with spaces"
    mkdir -p "$case_root/scripts" "$case_root/build/Ordo.app/Contents/MacOS"
    cp "$repo_root/scripts/dev-update.sh" "$repo_root/scripts/AppLifecycle.swift" "$case_root/scripts/"
    printf 'old\n' > "$case_root/build/Ordo.app/version"
    printf '旧假 App\n' > "$case_root/build/Ordo.app/Contents/MacOS/Ordo"
    printf '111\n' > "$case_root/running"
    : > "$case_root/events"
    : > "$case_root/output.log"
}

invoke_update() {
    env PATH="$stub_bin:$PATH" \
        ORDO_TEST_ROOT="$case_root" \
        ORDO_TEST_SCENARIO="$scenario" \
        ORDO_TEST_HELPER="$suite_root/app-lifecycle-stub" \
        /bin/bash "$case_root/scripts/dev-update.sh"
}

expect_failure() {
    if invoke_update > "$case_root/output.log" 2>&1; then
        fail '本场景应当返回失败'
    fi
}

passed=0
pass() {
    passed=$((passed + 1))
    printf '通过：%s\n' "$1"
}

prepare_case build_failure
expect_failure
assert_untouched
pass '构建失败保留旧 App 和进程'

prepare_case signature_failure
expect_failure
assert_untouched
pass '完整签名拒绝时不退出旧版'

prepare_case identity_failure
expect_failure
assert_untouched
pass '签名身份或配置拒绝时不退出旧版'

prepare_case success
invoke_update > "$case_root/output.log" 2>&1 || fail '正常更新失败'
assert_content "$case_root/build/Ordo.app/version" new
assert_content "$case_root/running" 222
assert_archived
assert_event 'stop old'
assert_event 'launch new'
pass '正常更新归档旧版并使用新 PID'

prepare_case quit_timeout
expect_failure
assert_content "$case_root/build/Ordo.app/version" old
assert_content "$case_root/running" 111
assert_no_event '^launch '
pass '旧版退出超时不替换、不强杀'

prepare_case other_path
expect_failure
assert_untouched
pass '其他路径运行的同 Bundle ID App 不被退出'

prepare_case replacement_failure
expect_failure
assert_file "$case_root/replacement-failed"
assert_content "$case_root/build/Ordo.app/version" old
assert_content "$case_root/running" 333
assert_event 'launch old'
assert_no_event '^launch new$'
pass '第二步替换失败恢复旧版并重新启动'

prepare_case launch_failure
expect_failure
assert_content "$case_root/build/Ordo.app/version" old
assert_content "$case_root/running" 333
assert_failed_candidate
assert_event 'stop new'
assert_event 'launch old'
pass '新版启动验证失败后退出候选、保留失败产物并恢复旧版'

prepare_case candidate_quit_failure
expect_failure
assert_content "$case_root/build/Ordo.app/version" new
assert_content "$case_root/running" 222
assert_archived
assert_no_event '^launch old$'
pass '候选无法退出时保留正在运行的候选和旧版归档'

prepare_case initially_stopped
printf '%s\n' - > "$case_root/running"
expect_failure
assert_content "$case_root/build/Ordo.app/version" old
assert_content "$case_root/running" -
assert_failed_candidate
assert_no_event '^launch old$'
pass '原先未运行时恢复文件但不自动启动旧版'

prepare_case concurrent
invoke_update > "$case_root/output.log" 2>&1 &
first_pid=$!
# 即使断言失败，也允许自建的模拟构建继续退出，不遗留等待进程。
trap 'touch "$case_root/release-build"; wait "$first_pid" 2>/dev/null || true' EXIT
for ((attempt = 0; attempt < 100; attempt++)); do
    [[ -f "$case_root/build-waiting" ]] && break
    sleep 0.05
done
assert_file "$case_root/build-waiting"
if invoke_update > "$case_root/concurrent.log" 2>&1; then
    fail '并发更新应被拒绝'
fi
[[ "$(/usr/bin/grep -c '^build$' "$case_root/events")" == 1 ]] || fail '第二个更新不应开始构建'
kill -0 "$first_pid" || fail '第一个更新不应被并发请求中断'
touch "$case_root/release-build"
wait "$first_pid" || fail '释放等待后第一个更新失败'
trap - EXIT
assert_content "$case_root/build/Ordo.app/version" new
pass '并发更新被锁拒绝且首个更新继续完成'

printf '%s 个隔离更新场景全部通过。\n' "$passed"
