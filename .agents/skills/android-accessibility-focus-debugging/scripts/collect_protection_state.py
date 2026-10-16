#!/usr/bin/env python3
"""Read-only Android evidence. Raw dumps, serials and other apps never enter output."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess


def component(value):
    if '/' not in value:
        return None
    package, service = value.strip().split('/', 1)
    return package + '/' + (package + service if service.startswith('.') else service)


def collect(read, package, service, user=0):
    target = component(service if '/' in service else package + '/' + service)
    if not target or target.split('/')[0] != package:
        raise ValueError('Service must belong to the requested package')
    errors = []

    def probe(name, *args):
        result = read(args)
        if result is None:
            errors.append(name)
        return result

    enabled = probe('enabled-setting', 'settings', '--user', str(user), 'get', 'secure', 'enabled_accessibility_services')
    accessibility = probe('accessibility-dump', 'dumpsys', 'accessibility')
    services = probe('own-services', 'dumpsys', 'activity', 'services', package)
    packages = probe('own-package', 'dumpsys', 'package', package)
    exits = probe('own-exit-info', 'dumpsys', 'activity', 'exit-info', package)
    pids = probe('own-process', 'pidof', package)
    os_version = {}
    for key, prop in [('android', 'ro.build.version.release'), ('api', 'ro.build.version.sdk'), ('firmware', 'ro.build.version.incremental')]:
        value = probe('system-' + key, 'getprop', prop)
        os_version[key] = value.strip()[:128] if value is not None else None

    enabled_value = None
    if enabled is not None:
        tokens = enabled.strip().split(':')
        if enabled.strip() in ('', 'null'):
            enabled_value = False
        elif all(re.fullmatch(r'[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+', v) for v in tokens):
            enabled_value = target in {component(v) for v in tokens}
        else:
            errors.append('enabled-setting-format')

    # Newer dumps can show only labels. A missing component is NOT a negative binding verdict.
    bound_visible = None
    if accessibility is not None:
        bound_rows = re.findall(r'Bound services:\{([^\n]*)', accessibility)
        for row in bound_rows:
            values = re.findall(r'[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+', row)
            if target in {component(value) for value in values}:
                bound_visible = True

    def match(pattern, text):
        return re.search(pattern, text, re.MULTILINE) if text is not None else None

    version = match(r'^\s*versionName=([^\r\n]+)', packages)
    code = match(r'\bversionCode=(\d+)', packages)
    user_row = match(r'^\s*User ' + str(user) + r':([^\r\n]*)', packages)
    stopped = match(r'\bstopped=(true|false)\b', user_row.group(1) if user_row else None)
    first_exit = exits.split('ApplicationExitInfo #0:', 1)[1].split('ApplicationExitInfo #1:', 1)[0] if exits and 'ApplicationExitInfo #0:' in exits else None
    stamp = match(r'timestamp=([0-9 :.-]+)\s+pid=', first_exit)
    reason = match(r'\breason=(\d+) \(([A-Z _-]+)\)', first_exit)
    subreason = match(r'\bsubreason=(\d+) \(([A-Z _-]+)\)', first_exit)
    latest = None if first_exit is None else {
        'timestampOnDevice': stamp.group(1).strip() if stamp else None,
        'reasonCode': int(reason.group(1)) if reason else None,
        'reason': reason.group(2) if reason else None,
        'subreasonCode': int(subreason.group(1)) if subreason else None,
        'subreason': subreason.group(2) if subreason else None,
        'swipeUpCleanMentioned': 'SwipeUpClean' in first_exit,
    }
    service_present = foreground = None
    if services is not None:
        if re.search(r'\bServiceRecord\{[^\n]*' + re.escape(package), services):
            service_present = True
            foreground = 'isForeground=true' in services
        elif 'ACTIVITY MANAGER SERVICES' in services:
            service_present = foreground = False
        else:
            errors.append('own-services-format')
    return {
        'checkedAtUtc': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'package': package, 'service': target, 'user': user, 'system': os_version,
        'versionName': version.group(1).strip()[:128] if version else None,
        'versionCode': int(code.group(1)) if code else None,
        'packageStopped': stopped.group(1) == 'true' if stopped else None,
        'processPresent': bool(pids.strip()) if pids is not None and (not pids.strip() or re.fullmatch(r'[\d\s]+', pids)) else None,
        'accessibility': {'enabled': enabled_value, 'boundComponentVisible': bound_visible},
        'serviceRecordPresent': service_present,
        'foregroundService': foreground,
        'latestExit': latest, 'errors': errors,
        'limits': ['Snapshot only; verify application status and actual blocking separately',
                   'Bound component may be omitted or not user-scoped in the system dump; null remains unknown',
                   'No raw dumps, other-service lists, page contents, database or device serial are exported'],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', required=True, help='Existing adb executable')
    parser.add_argument('--package', required=True)
    parser.add_argument('--service', required=True, help='Relative service class or same-package component')
    parser.add_argument('--user', type=int, default=0)
    parser.add_argument('--serial', help='Used only to select device; omitted from output')
    parser.add_argument('--out', type=Path, help='Private output JSON; stdout when omitted')
    parser.add_argument('--apk', type=Path, help='Optional local APK hash, not an installed-package comparison')
    parser.add_argument('--timeout', type=float, default=20)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+', args.package):
        parser.error('Invalid package name')
    if args.user < 0 or args.timeout <= 0:
        parser.error('User and timeout must be valid positive values (user may be zero)')
    base = [args.adb] + (['-s', args.serial] if args.serial else [])

    def read(command):
        try:
            result = subprocess.run(base + ['shell', *command], capture_output=True, timeout=args.timeout, check=False)
        except (OSError, subprocess.TimeoutExpired):
            return None
        if result.returncode == 1 and command[0] == 'pidof' and not result.stdout.strip() and not result.stderr.strip():
            return ''
        text = result.stdout.decode('utf-8', errors='replace') if result.returncode == 0 else None
        if text and re.search(r'(?im)^(?:error:|exception|permission denial|java\.[a-z.]*exception)', text):
            return None
        return text

    try:
        result = collect(read, args.package, args.service, args.user)
    except ValueError as error:
        parser.error(str(error))
    if args.apk:
        try:
            result['localApkSha256'] = hashlib.sha256(args.apk.read_bytes()).hexdigest()
        except OSError:
            parser.error('Cannot read local APK; no device changes were made')
    payload = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(payload, encoding='utf-8')
        print('Wrote sanitized diagnostic snapshot')
    else:
        print(payload, end='')
    return 2 if result['errors'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
