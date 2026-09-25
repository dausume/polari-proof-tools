# polari-proof-tools — THE FORMAL PROOF TOOLCHAIN Polari's `mathproofs` module checks its Lean certificates with
# (plan §I, pf-2; D-pf-5 its own submodule beside polari-eda-tools; D-pf-11 the pins live HERE and never float):
#
#   elan                      Apache-2.0 / MIT   the Lean toolchain installer (installs exactly `lean-toolchain`)
#   Lean 4 v4.34.1            Apache-2.0         the checker (`lean-toolchain`)
#   Mathlib @ d13f23b7 (v4.34.1)  Apache-2.0     the library, at ONE commit (`lake-manifest.json`); its compiled
#                                                oleans are fetched into the image by `lake exe cache get` — several
#                                                GB, the honest cost of a checker that answers in seconds instead of
#                                                hours; the cache is a build-time download, never in git
#   theorems/                 ours (GPLv3)       the certificates the framework's MathClaims cite by statement_hash
#
# Every use is a separate process (`lake env lean <file>` through flows/check.sh); nothing here is linked into or
# vendored by Polari — LICENSES.md. Build once, big; check in seconds:
#   docker build -t polari-proof-tools:noble .
#   docker run --rm polari-proof-tools:noble flows/check.sh theorems/PolariProofs/RestrictionIdempotent.lean
# As a service (docker-compose.proof-engines.yml in polari-rf-node): the engines WORKER on :9810.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 ELAN_HOME=/opt/elan PATH=/opt/elan/bin:$PATH \
    POLARI_PROOF_PROJECT=/proofs
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git ca-certificates python3 python3-pip \
    && pip3 install --no-cache-dir --break-system-packages falcon gunicorn \
    && rm -rf /var/lib/apt/lists/*
# elan installs exactly the toolchain the project pins (lean-toolchain) — no default, nothing floats
RUN curl -sSfL https://elan.lean-lang.org/elan-init.sh | sh -s -- -y --default-toolchain none --no-modify-path
WORKDIR /proofs
COPY lean-toolchain lakefile.toml ./
COPY lake-manifest.json* ./
# 1. the toolchain named by lean-toolchain; 2. Mathlib at the manifest's commit (or, on the very first build without a
#    manifest, at the lakefile's rev — the manifest that results is what gets committed); 3. the compiled oleans
#    (the download itself sits in a BuildKit cache mount, so a rebuild that changes only the pins' files re-fetches
#    nothing it already has; the image never carries the tarballs, only the unpacked oleans)
RUN --mount=type=cache,target=/root/.cache/mathlib \
    elan toolchain install "$(cat lean-toolchain)" \
    && lake update mathlib \
    && lake exe cache get
# our theorems, built at image build time: the image does not exist unless every committed certificate checks
COPY theorems/ theorems/
COPY flows/ flows/
RUN chmod +x flows/*.sh && lake build PolariProofs && mkdir -p theorems/_jobs && chmod 1777 theorems/_jobs
COPY proof_engines_service.py /srv/proof_engines_service.py
EXPOSE 9810
CMD ["gunicorn", "-b", "0.0.0.0:9810", "-w", "2", "-t", "1800", "--chdir", "/srv", "proof_engines_service:app"]
