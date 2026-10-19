#!/usr/bin/env python3
"""Explicit isolated-simulator experiment. Pass a private file containing its owned UDID."""
import argparse, hashlib, json, pathlib, subprocess, time, uuid
p = argparse.ArgumentParser()
p.add_argument('--simulator-id-file', type=pathlib.Path, required=True)
p.add_argument('--artifacts', type=pathlib.Path, required=True)
a = p.parse_args(); a.artifacts.mkdir(parents=True, exist_ok=True)
sim = a.simulator_id_file.read_text().strip()
bundle = 'app.getbb.voiceprobe.phase0'
def simctl(*args, check=True):
    r = subprocess.run(['xcrun','simctl',*args], text=True, capture_output=True)
    with (a.artifacts/'commands-private.log').open('a') as f:
        f.write(json.dumps(dict(args=args, code=r.returncode, stdout=r.stdout, stderr=r.stderr))+'\n')
    if check and r.returncode: raise RuntimeError(r.stderr)
    return r.stdout.strip()
def container():
    return pathlib.Path(simctl('get_app_container',sim,bundle,'data'))/'Library/Application Support/NativePhase0'
def load(name):
    path=container()/name
    return json.loads(path.read_text()) if path.exists() else []
def wait_for(predicate, seconds=20):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        if predicate(): return True
        time.sleep(.2)
    return False
def records(): return load('Transfers/transfers.json')
def launch(*args): simctl('launch',sim,bundle,*args)
def stop(): simctl('terminate',sim,bundle,check=False)
def requests(root):
    f=root/'requests.jsonl'
    return [json.loads(x) for x in f.read_text().splitlines()] if f.exists() else []
servers=[]
result={'environment':'isolated watchOS simulator, real background URLSession', 'hardware_G4':'NOT RUN', 'cases':[]}
try:
    for mode in ['completion','termination-after-intake']:
        sink=a.artifacts/mode; sink.mkdir(exist_ok=True)
        release=sink/'release'
        cmd=['python3','native/scripts/fixture_server.py','--root',str(sink)]
        if mode!='completion': cmd+=['--hold-response',str(release)]
        server=subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=(sink/'server.log').open('w'), text=True)
        servers.append(server)
        endpoint=server.stdout.readline().strip()
        assert endpoint.startswith('http://127.0.0.1:') and server.poll() is None
        request=str(uuid.uuid4()); stop(); launch('--fixture-upload',endpoint,request)
        observed=wait_for(lambda:any(x['id'].lower()==request for x in records()))
        case={'case':mode,'durable_plan_observed':observed}
        if not observed:
            case['result']='No durable plan within 20s'; result['cases'].append(case); break
        arrived=wait_for(lambda:len(requests(sink))>0)
        case['sink_arrived']=arrived
        before_relaunch = len(load('transfer-events.json'))
        if mode=='termination-after-intake' and arrived:
            stop(); release.touch(); launch('--fixture-upload',endpoint,request)
        else:
            wait_for(lambda:any(x['id'].lower()==request and x['phase']=='observed' for x in records()))
            stop(); launch() # ordinary recreation never creates a new fixture request
        case['relaunch_reconciled'] = wait_for(lambda:any(x['stage']=='getAllTasks' for x in load('transfer-events.json')[before_relaunch:]),5)
        time.sleep(1)
        record=next(x for x in records() if x['id'].lower()==request)
        body=container()/'Transfers'/record['filename']
        case.update(phase=record['phase'], http_status=record.get('httpStatus'), error_code=record.get('errorCode'),
                    sink_requests=len(requests(sink)), body_retained=body.exists(), body_sha256=hashlib.sha256(body.read_bytes()).hexdigest())
        assert case['body_sha256']==record['sha256'] and case['body_retained']
        assert case['sink_requests']<=1, 'unexpected replay reached sink'
        case['result']='native observation' if case['http_status']==200 else 'unresolved or native error; not an acceptance proof'
        result['cases'].append(case)
        if not arrived: break # one exact native failure is enough; no endless simulator retries
    (a.artifacts/'ledger-private.json').write_text(json.dumps(records(),indent=2))
    (a.artifacts/'events-private.json').write_text(json.dumps(load('transfer-events.json'),indent=2))
finally:
    stop(); launch('--fixture-cancel')
    time.sleep(2); stop()
    for server in servers:
        server.terminate(); server.wait(timeout=5)
    (a.artifacts/'result.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
