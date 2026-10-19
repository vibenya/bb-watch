#!/usr/bin/env python3
"""Authorized isolated simulator only. Install separately; never boots a device."""
import argparse, json, pathlib, shutil, subprocess, time
p = argparse.ArgumentParser()
p.add_argument('--simulator-id-file', type=pathlib.Path, required=True)
p.add_argument('--artifacts', type=pathlib.Path, required=True)
a = p.parse_args(); a.artifacts.mkdir(parents=True, exist_ok=True)
sim = a.simulator_id_file.read_text().strip()
bundle = 'app.getbb.voiceprobe.phase0'
def run(*args, check=True):
    r = subprocess.run(['xcrun', 'simctl', *args], capture_output=True, text=True)
    with (a.artifacts/'commands-private.log').open('a') as log:
        log.write(json.dumps(dict(args=args, code=r.returncode, stdout=r.stdout, stderr=r.stderr))+'\n')
    if check and r.returncode: raise RuntimeError('simctl failed; see private command log')
    return r.stdout.strip()
base = pathlib.Path(run('get_app_container', sim, bundle, 'data'))/'Library/Application Support/NativePhase0'
old = set(base.glob('Codec-*'))
try:
    run('terminate', sim, bundle, check=False)
    run('launch', sim, bundle, '--codec-fixtures')
    end = time.monotonic() + 30
    while time.monotonic() < end:
        reports = [x/'codec-report.json' for x in set(base.glob('Codec-*'))-old if (x/'codec-report.json').exists()]
        if reports: break
        time.sleep(.5)
    else: raise RuntimeError('No new codec report within 30 seconds; no success inferred')
    shutil.copytree(reports[0].parent, a.artifacts/'fixtures', dirs_exist_ok=True)
    report = json.loads(reports[0].read_text())
    for case in report['cases']: print(case['name'] + ': ' + case['outcome'])
    assert sum(x['outcome']=='measured-candidate' for x in report['cases']) == 6
    assert sum(x['outcome']=='expected-hold-source-retained' for x in report['cases']) == 4
    assert report['chronologicalBoundaryPassed']
    print('PASS watch simulator native AAC-LC: six candidates, four retained-source failures, chronological boundary')
finally:
    run('terminate', sim, bundle, check=False)
