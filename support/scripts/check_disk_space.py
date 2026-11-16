#!/usr/bin/env python3
"""
Mesh Disk Space Safety Guard
Prevents build operations from running when disk capacity is below safety thresholds.
"""
import sys
import shutil

def check_drive(drive, critical_gb=15, warning_gb=25):
    try:
        usage = shutil.disk_usage(drive)
        free_gb = round(usage.free / (1024**3), 2)
        total_gb = round(usage.total / (1024**3), 2)
        used_gb = round(usage.used / (1024**3), 2)
        pct = round((usage.free / usage.total) * 100, 1)
        
        print(f"Drive {drive} Total: {total_gb} GB | Used: {used_gb} GB | Free: {free_gb} GB ({pct}%)")
        
        if free_gb < 8:
            print(f"[EMERGENCY] Drive {drive} has only {free_gb} GB free (< 8 GB)! Aborting.", file=sys.stderr)
            return False
        elif free_gb < critical_gb:
            print(f"[CRITICAL] Drive {drive} has only {free_gb} GB free (< {critical_gb} GB)! Aborting.", file=sys.stderr)
            return False
        elif free_gb < warning_gb:
            print(f"[WARNING] Drive {drive} is below {warning_gb} GB free ({free_gb} GB remaining).")
            return True
        else:
            print(f"[HEALTHY] Drive {drive} free space is satisfactory ({free_gb} GB).")
            return True
    except Exception as e:
        print(f"Could not check drive {drive}: {e}", file=sys.stderr)
        return True

def main():
    print("=== Mesh Development Storage Guard ===")
    c_ok = check_drive("C:\\")
    d_ok = check_drive("D:\\")
    if not (c_ok and d_ok):
        print("\nStorage protection triggered! Aborting operation.", file=sys.stderr)
        sys.exit(1)
    print("\nAll drive checks passed. Safe to proceed.")
    sys.exit(0)

if __name__ == '__main__':
    main()
