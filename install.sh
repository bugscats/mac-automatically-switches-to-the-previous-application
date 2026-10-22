#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
build_app="$source_dir/.build/切回上一个应用.app"
installed_app="/Applications/切回上一个应用.app"
support_dir="$HOME/Library/Application Support/TaixuPreviousAppSwitcher"
agent_path="$HOME/Library/LaunchAgents/local.taixu.previous-app-switcher.plist"
service="gui/$(id -u)/local.taixu.previous-app-switcher"

# Do not overwrite an unrelated app or launch agent with the same filename.
python3 - "$installed_app" "$agent_path" <<'PY'
import plistlib, sys
from pathlib import Path
app, agent = map(Path, sys.argv[1:])
if app.exists():
    with (app / 'Contents/Info.plist').open('rb') as f:
        bundle = plistlib.load(f)['CFBundleIdentifier']
    if bundle not in ('local.taixu.previous-app-switcher', 'local.taixu.switch-previous-app'):
        raise SystemExit('同名应用不属于本工具，已停止安装。')
if agent.exists():
    with agent.open('rb') as f:
        if plistlib.load(f).get('Label') != 'local.taixu.previous-app-switcher':
            raise SystemExit('同名启动项不属于本工具，已停止安装。')
PY
bash "$source_dir/build.sh"
mkdir -p "$support_dir" "$(dirname "$agent_path")"
if [[ -d "$installed_app" && ! -e "$support_dir/original-applescript.app" ]] \
    && [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$installed_app/Contents/Info.plist")" == applet ]]; then
    ditto "$installed_app" "$support_dir/original-applescript.app"
fi
rollback_dir="$(mktemp -d "$source_dir/.build/install.XXXXXX")"
had_app=false
had_agent=false
was_loaded=false
was_disabled=false
was_running="$(python3 "$source_dir/stop-app.py" --check)"
if [[ -d "$installed_app" ]]; then
    ditto "$installed_app" "$rollback_dir/application.app"
    had_app=true
fi
if [[ -f "$agent_path" ]]; then
    cp "$agent_path" "$rollback_dir/agent.plist"
    had_agent=true
fi
if launchctl print "$service" >/dev/null 2>&1; then was_loaded=true; fi
if launchctl print-disabled "gui/$(id -u)" | /usr/bin/grep -q '"local.taixu.previous-app-switcher" => \(true\|disabled\)'; then
    was_disabled=true
fi
rollback() {
    local failure=$?
    trap - ERR
    set +e
    launchctl bootout "$service" 2>/dev/null
    python3 "$source_dir/stop-app.py"
    if [[ -e "$installed_app" ]]; then mv "$installed_app" "$rollback_dir/failed.app"; fi
    if $had_app; then ditto "$rollback_dir/application.app" "$installed_app"; fi
    if $had_agent; then
        cp "$rollback_dir/agent.plist" "$agent_path"
        launchctl enable "$service"
        if $was_loaded; then launchctl bootstrap "gui/$(id -u)" "$agent_path"; fi
    elif [[ -f "$agent_path" ]]; then
        mv "$agent_path" "$rollback_dir/failed-agent.plist"
    fi
    if $was_disabled; then launchctl disable "$service"; fi
    if ! $was_loaded && [[ "$was_running" -gt 0 ]] && $had_app; then open "$installed_app"; fi
    echo "安装失败：已尝试恢复原应用与原启动项。备份：$rollback_dir" >&2
    exit "$failure"
}
trap rollback ERR
launchctl bootout "$service" 2>/dev/null || true
python3 "$source_dir/stop-app.py"
if [[ -e "$installed_app" ]]; then mv "$installed_app" "$rollback_dir/replaced.app"; fi
ditto "$build_app" "$installed_app"
python3 - "$agent_path" "$installed_app/Contents/MacOS/PreviousAppSwitcher" <<'PY'
import plistlib, sys
agent = {
    'Label': 'local.taixu.previous-app-switcher',
    'ProgramArguments': [sys.argv[2]],
    'RunAtLoad': True, 'KeepAlive': True, 'ProcessType': 'Interactive',
    'LimitLoadToSessionType': 'Aqua', 'ThrottleInterval': 5,
}
with open(sys.argv[1], 'wb') as output:
    plistlib.dump(agent, output)
PY
chmod 644 "$agent_path"
plutil -lint "$agent_path"
launchctl enable "$service"
launchctl bootstrap "gui/$(id -u)" "$agent_path"
if $was_disabled; then launchctl disable "$service"; fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$installed_app"
launchctl print "$service" | awk '/state =|pid =|last exit code|runs =/ { print }'
trap - ERR
echo '安装完成；原有暂停、区域和登录启动偏好已保留。'
