"""
proof-engines — the PROOF engines WORKER of polari-proof-tools (the Polari engines pattern, exactly as eda-engines /
cnt-engines): the pinned Lean 4 + Mathlib behind one JSON API, so the framework's `lean` proof tier
(polari-framework/modules/mathproofs/custom/lean_tier.py) runs on WHATEVER device the topology assigns
(`pol allocate mathproofs.engines <instance>`) while the core keeps the claim rows. The backend resolves through
mathproofs/custom/proof_engines.py — ladder: PROOF_ENGINES_URL knob wins; else a local lake project + binary; else
the local image; else the topology's provider; else an honest refusal. Lean is NEVER run automatically by the
framework (plan §I.9): a person or the pipeline asks.

  GET  /capability      {engines: {lean: {available, version}}, pins: {lean, mathlib}, theorems: [{file, sha256,
                         statement_hash, term}], project}
  GET  /system-info     res-1 shape (cpu/mem) like the other workers
  POST /check           {"file": "PolariProofs/<Name>.lean"} | {"source": "<lean text>", "name": "<Job>"},
                         "statement_hash": "<sha256 the claim carries>", "timeout": s
                        -> {ok, verdict: proved|error|timeout, returncode, stdout, stderr, file, file_sha256,
                            statement_hash_in_file, hash_matches, pins, elapsed_s}
                        A file is a path INSIDE theorems/ (never '..', never absolute); a source job is written under
                        theorems/_jobs/ and removed afterwards. `hash_matches` is the bridge: the verdict is only a
                        certificate for the claim whose statement_hash the file header cites.
"""
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import tempfile
import time

import falcon

PROJECT = os.environ.get('POLARI_PROOF_PROJECT', '/proofs')
THEOREMS = os.path.join(PROJECT, 'theorems')
CHECK = os.path.join(PROJECT, 'flows', 'check.sh')
TAIL = 20000
MAX_SOURCE = 1024 * 1024


def _pins():
    lean = ''
    try:
        lean = open(os.path.join(PROJECT, 'lean-toolchain')).read().strip()
    except Exception:
        pass
    ml = ''
    try:
        m = json.load(open(os.path.join(PROJECT, 'lake-manifest.json')))
        ml = next((p.get('rev', '') for p in m.get('packages', []) if p.get('name') == 'mathlib'), '')
    except Exception:
        pass
    return {'lean': lean, 'mathlib': ml}


def _lean_version():
    try:
        r = subprocess.run(['lake', 'env', 'lean', '--version'], capture_output=True, text=True, timeout=60, cwd=PROJECT)
        return (r.stdout or r.stderr).strip().splitlines()[0][:120]
    except Exception:
        return ''


def _header(path):
    """(statement_hash, term) from a theorem file's header — the readable bridge."""
    h, t = '', ''
    try:
        for line in open(path, errors='replace').read().splitlines()[:40]:
            if line.startswith('POLARI_STATEMENT_HASH '):
                h = line.split()[1].strip()
            elif line.startswith('POLARI_TERM '):
                t = line[len('POLARI_TERM '):].strip()
    except Exception:
        pass
    return h, t


def _sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest()


def _theorems():
    out = []
    for root, _, names in os.walk(THEOREMS):
        if '_jobs' in root or '.lake' in root:
            continue
        for fn in sorted(names):
            if fn.endswith('.lean'):
                p = os.path.join(root, fn); h, t = _header(p)
                out.append({'file': os.path.relpath(p, THEOREMS), 'sha256': _sha(p), 'statement_hash': h, 'term': t})
    return out


def _process_block():
    """res-3 contract: this worker process's resident / peak RSS from /proc/self/status (residentMb, peakMb)."""
    out = {}
    try:
        for line in open('/proc/self/status'):
            if line.startswith('VmRSS:'):
                out['residentMb'] = round(int(line.split()[1]) / 1024.0, 1)
            elif line.startswith('VmHWM:'):
                out['peakMb'] = round(int(line.split()[1]) / 1024.0, 1)
    except Exception:
        pass
    return out


class CapabilityResource:
    def on_get(self, req, resp):
        v = _lean_version()
        resp.media = {'worker': 'proof-engines', 'engines': {'lean': {'available': bool(v), 'version': v, 'binary': 'lake env lean'}}, 'resources': {'ramMb': 2000, 'minThreads': 1, 'threadCeiling': 4, 'cpuBenefit': 'sublinear', 'imageMb': 11000, 'fidelity': 'declared', 'note': 'res-2 block (rc-1): Lean + Mathlib oleans; RAM-bound per check'}, 'pins': _pins(), 'project': PROJECT,
                      'theorems': _theorems(), 'protocol': 'POST /check {file | source+name, statement_hash, timeout} — one file, inside the pinned project; the verdict is a certificate only when hash_matches'}


class SystemInfoResource:
    def on_get(self, req, resp):
        info = {}
        try:
            for line in open('/proc/meminfo'):
                k, _, v = line.partition(':'); info[k.strip()] = int(v.strip().split()[0]) * 1024
        except Exception:
            pass
        resp.media = {'process': _process_block(), 'ok': True, 'worker': 'proof-engines', 'cpus': os.cpu_count(), 'memTotalBytes': info.get('MemTotal', 0), 'memAvailableBytes': info.get('MemAvailable', 0), 'platform': platform.platform()}


def _bad(resp, msg, status=falcon.HTTP_400):
    resp.status = status; resp.media = {'ok': False, 'error': msg}


class CheckResource:
    def on_post(self, req, resp):
        body = req.get_media() or {}
        timeout = int(body.get('timeout') or 600)
        want = str(body.get('statement_hash') or '')
        job = None
        if body.get('file'):
            rel = str(body['file'])
            if rel.startswith('/') or '..' in rel or not rel.endswith('.lean'):
                return _bad(resp, 'file must be a .lean path inside theorems/')
            path = os.path.join(THEOREMS, rel)
            if not os.path.isfile(path):
                return _bad(resp, 'no such theorem file %r' % rel, falcon.HTTP_404)
        elif body.get('source'):
            src = str(body['source'])
            if len(src) > MAX_SOURCE:
                return _bad(resp, 'source exceeds 1 MB', falcon.HTTP_413)
            name = re.sub(r'[^A-Za-z0-9_]', '', str(body.get('name') or 'Job')) or 'Job'
            jobs = os.path.join(THEOREMS, '_jobs'); os.makedirs(jobs, exist_ok=True)
            job = tempfile.mkdtemp(prefix='job-', dir=jobs)
            path = os.path.join(job, name + '.lean'); open(path, 'w').write(src); rel = os.path.relpath(path, THEOREMS)
        else:
            return _bad(resp, 'give "file" (inside theorems/) or "source" + "name"')
        try:
            t0 = time.time()
            try:
                run = subprocess.run([CHECK, os.path.relpath(path, PROJECT), str(timeout)], capture_output=True, text=True, timeout=timeout + 30, cwd=PROJECT)
                rc, out, err = run.returncode, run.stdout or '', run.stderr or ''
            except subprocess.TimeoutExpired as exc:
                rc, out, err = 124, (exc.stdout or b'').decode(errors='replace') if isinstance(exc.stdout, bytes) else (exc.stdout or ''), 'timeout'
            elapsed = round(time.time() - t0, 3)
            m = re.search(r'^POLARI_PROOF (ok|error) (\S+)', out, re.M)
            h_in_file, term = _header(path)
            verdict = 'timeout' if rc == 124 else ('proved' if (m and m.group(1) == 'ok' and rc == 0) else 'error')
            resp.media = {'ok': True, 'verdict': verdict, 'returncode': rc, 'stdout': out[-TAIL:], 'stderr': err[-TAIL:], 'file': rel, 'file_sha256': _sha(path),
                          'statement_hash_in_file': h_in_file, 'term_in_file': term, 'hash_matches': bool(want) and want == h_in_file, 'pins': _pins(), 'elapsed_s': elapsed, 'timeout_s': timeout}
        finally:
            if job:
                shutil.rmtree(job, ignore_errors=True)


app = falcon.App()
app.add_route('/capability', CapabilityResource())
app.add_route('/system-info', SystemInfoResource())
app.add_route('/check', CheckResource())
