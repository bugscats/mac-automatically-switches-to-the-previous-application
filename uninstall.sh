#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
app_path="/Applications/切回上一个应用.app"
agent_path="$HOME/Library/LaunchAgents/local.taixu.previous-app-switcher.plist"
service="gui/$(id -u)/local.taixu.previous-app-switcher"
python3 - "$app_path" "$agent_path" <<'PY'
import plistlib, sys
from pathlib import Path
app, agent = map(Path, sys.argv[1:])
if app.exists():
    with (app / 'Contents/Info.plist').open('rb') as f:
        if plistlib.load(f).get('CFBundleIdentifier') != 'local.taixu.previous-app-switcher':
            raise SystemExit('同名应用不属于原生切换工具，已停止卸载。')
if agent.exists():
    with agent.open('rb') as f:
        if plistlib.load(f).get('Label') != 'local.taixu.previous-app-switcher':
            raise SystemExit('同名启动项不属于本工具，已停止卸载。')
PY
if launchctl print "$service" >/dev/null 2>&1; then launchctl bootout "$service"; fi
# A manually reopened copy may not be owned by launchd.
python3 "$source_dir/stop-app.py"
python3 - "$app_path" "$agent_path" <<'PY'
import shutil, sys, uuid
from pathlib import Path
app, agent = map(Path, sys.argv[1:])
trash = Path.home() / '.Trash' / ('PreviousAppSwitcher-' + uuid.uuid4().hex[:8])
trash.mkdir(parents=True)
for item in (app, agent):
    if item.exists():
        shutil.move(str(item), str(trash / item.name))
print('已停止并移入废纸篓：' + str(trash))
print('区域偏好和旧版备份已保留；重新安装即可恢复。')
PY
