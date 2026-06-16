#!/usr/bin/env python3
"""Deploy pgBackRest dashboard JSON to Grafana API."""
import base64
import json
import sys
import urllib.request


def main():
    if len(sys.argv) < 2:
        print("Usage: deploy-backrest-dashboard.py <dashboard.json>")
        sys.exit(1)

    with open(sys.argv[1]) as f:
        dashboard = json.load(f)

    payload = {
        "dashboard": dashboard,
        "overwrite": True,
        "message": "Fix Backup Inventory: join queries A-E on backup_name",
    }

    req = urllib.request.Request(
        "http://127.0.0.1:3000/api/dashboards/db",
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Basic "
            + base64.b64encode(b"admin:Admin@123").decode(),
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read().decode())
            print(json.dumps(result, indent=2))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
        print(f"HTTP {exc.code}: {body}")
        raise


if __name__ == "__main__":
    main()