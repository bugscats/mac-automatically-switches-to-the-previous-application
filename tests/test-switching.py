"""Exercise the installed service by moving the real pointer into its left zone."""
import json
from pathlib import Path
import subprocess

driver = Path(__file__).resolve().parents[1] / ".build/drive-edge"
subprocess.run([str(driver), "--center"], check=True)
subprocess.run(["osascript", "-e", '''
tell application id "com.microsoft.VSCode" to activate
delay 0.3
tell application id "com.google.Chrome" to activate
delay 0.3
'''], check=True)

results = []
for _ in range(6):
    completed = subprocess.run([str(driver), "--pair", "200"], text=True, capture_output=True)
    if completed.returncode == 2:
        raise SystemExit(completed.stderr + completed.stdout)
    result = json.loads(completed.stdout)
    results.append(result)
    print(json.dumps(result, sort_keys=True), flush=True)
    if completed.returncode:
        raise SystemExit("Switching, latency, or one-trigger-per-entry check failed")
print(json.dumps({"passed": len(results), "maximum_ms": max(r["elapsed_ms"] for r in results)}))
