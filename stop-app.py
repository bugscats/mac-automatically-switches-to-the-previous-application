"""Stop only this tool's installed executable, including a manually reopened copy."""
import os
import signal
import subprocess
import sys
import time

expected = "/Applications/切回上一个应用.app/Contents/MacOS/PreviousAppSwitcher"


def running():
    output = subprocess.check_output(["ps", "-u", str(os.getuid()), "-o", "pid=,comm="], text=True)
    found = []
    for line in output.splitlines():
        pid, _, executable = line.strip().partition(" ")
        if executable.strip() == expected:
            found.append(int(pid))
    return found


pids = running()
if "--check" in sys.argv:
    print(len(pids))
else:
    for pid in pids:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 2
    while running():
        if time.monotonic() >= deadline:
            raise SystemExit("旧进程未能停止，已中止替换应用。")
        time.sleep(0.05)
