#!/usr/bin/env python3
"""Create (or reuse) the Two Do Xcode Cloud 'PR Build & Test' workflow via ASC API.

Requires env:
  ASC_KEY_ID       App Store Connect API Key ID
  ASC_ISSUER_ID    Issuer UUID (Users and Access → Integrations → App Store Connect API)
  ASC_KEY_P8       AuthKey_*.p8 contents, OR base64 of that file (GitHub Actions style)

Optional env:
  ASC_BUNDLE_ID          default com.kadeem.twodo
  ASC_WORKFLOW_NAME      default "PR Build & Test"
  ASC_SCHEME             default TwoDo
  ASC_CONTAINER_PATH     default TwoDo.xcodeproj
  ASC_REPO_OWNER         default kadeemj
  ASC_REPO_NAME          default two-do
  ASC_DEST_BRANCH        default main
  ASC_KEY_PATH           path to .p8 instead of ASC_KEY_P8

One-time prerequisites Apple does not expose via API:
  1. App Store Connect → Two Do (T2Do) → Xcode Cloud → Get Started
  2. Grant the Xcode Cloud GitHub App access to kadeemj/two-do

Exit codes:
  0 success (created or already exists)
  2 missing Xcode Cloud product / GitHub repo (action required in ASC)
  1 other API / config error
"""

from __future__ import annotations

import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

ASC_BASE = "https://api.appstoreconnect.apple.com"


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    assert der[0] == 0x30
    idx = 2
    if der[1] & 0x80:
        idx = 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        assert der[idx] == 0x02
        ln = der[idx + 1]
        val = der[idx + 2 : idx + 2 + ln]
        val = val.lstrip(b"\x00").rjust(32, b"\x00")
        out += val
        idx += 2 + ln
    return out


def mint_jwt(key_id: str, issuer_id: str, key_pem: str) -> str:
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    signing_input = f"{b64url(json.dumps(header, separators=(',', ':')).encode())}.{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    with tempfile.NamedTemporaryFile("w", suffix=".p8", delete=False) as kf:
        kf.write(key_pem)
        key_path = kf.name
    with tempfile.NamedTemporaryFile(suffix=".sig", delete=False) as sf:
        sig_path = sf.name
    try:
        subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_path, "-out", sig_path],
            input=signing_input.encode(),
            check=True,
            capture_output=True,
        )
        with open(sig_path, "rb") as f:
            der_sig = f.read()
    finally:
        os.unlink(key_path)
        os.unlink(sig_path)
    return f"{signing_input}.{b64url(der_to_raw(der_sig))}"


def load_key_pem() -> str:
    path = os.environ.get("ASC_KEY_PATH")
    if path:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    raw = os.environ.get("ASC_KEY_P8", "").strip()
    if not raw:
        raise SystemExit("Set ASC_KEY_P8 or ASC_KEY_PATH")
    if "BEGIN PRIVATE KEY" in raw:
        return raw if raw.endswith("\n") else raw + "\n"
    # GitHub Actions stores base64 of the .p8 file
    try:
        decoded = base64.b64decode(raw).decode("utf-8")
        if "BEGIN PRIVATE KEY" in decoded:
            return decoded if decoded.endswith("\n") else decoded + "\n"
    except Exception:
        pass
    raise SystemExit("ASC_KEY_P8 must be PEM text or base64(PEM)")


def asc_request(jwt: str, method: str, path: str, body: dict | None = None) -> dict:
    url = ASC_BASE + path
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {jwt}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode()
        try:
            parsed = json.loads(detail)
        except Exception:
            parsed = {"raw": detail}
        raise RuntimeError(f"ASC {method} {path} → HTTP {e.code}: {json.dumps(parsed, indent=2)}") from None


def find_app(jwt: str, bundle_id: str) -> dict:
    q = urllib.parse.urlencode({"filter[bundleId]": bundle_id, "limit": 10})
    data = asc_request(jwt, "GET", f"/v1/apps?{q}")
    apps = data.get("data") or []
    if not apps:
        raise SystemExit(f"No App Store Connect app for bundle id {bundle_id}")
    return apps[0]


def find_product(jwt: str, app_id: str) -> dict | None:
    q = urllib.parse.urlencode({"filter[app]": app_id, "limit": 10})
    data = asc_request(jwt, "GET", f"/v1/ciProducts?{q}")
    products = data.get("data") or []
    return products[0] if products else None


def find_repo(jwt: str, owner: str, name: str) -> dict | None:
    data = asc_request(jwt, "GET", "/v1/scmRepositories?limit=200")
    for repo in data.get("data") or []:
        attrs = repo.get("attributes") or {}
        if attrs.get("ownerName") == owner and attrs.get("repositoryName") == name:
            return repo
    return None


def latest_xcode(jwt: str) -> dict:
    data = asc_request(jwt, "GET", "/v1/ciXcodeVersions?limit=200")
    versions = data.get("data") or []
    if not versions:
        raise SystemExit("No ciXcodeVersions available")
    for v in versions:
        if (v.get("attributes") or {}).get("isLatestRelease"):
            return v
    return versions[0]


def compatible_macos(jwt: str, xcode_id: str) -> dict:
    data = asc_request(jwt, "GET", f"/v1/ciXcodeVersions/{xcode_id}/macOsVersions?limit=50")
    versions = data.get("data") or []
    if versions:
        return versions[0]
    data = asc_request(jwt, "GET", "/v1/ciMacOsVersions?limit=50")
    versions = data.get("data") or []
    if not versions:
        raise SystemExit("No ciMacOsVersions available")
    return versions[0]


def list_workflows(jwt: str, product_id: str) -> list[dict]:
    data = asc_request(jwt, "GET", f"/v1/ciProducts/{product_id}/workflows?limit=200")
    return data.get("data") or []


def create_workflow(
    jwt: str,
    *,
    product_id: str,
    repository_id: str,
    xcode_id: str,
    macos_id: str,
    name: str,
    scheme: str,
    container: str,
    dest_branch: str,
) -> dict:
    body = {
        "data": {
            "type": "ciWorkflows",
            "attributes": {
                "name": name,
                "description": "Build + test Two Do on PRs to main (no TestFlight — that stays on GitHub Actions).",
                "isEnabled": True,
                "isLockedForEditing": False,
                "clean": True,
                "containerFilePath": container,
                "actions": [
                    {
                        "name": "Build",
                        "actionType": "BUILD",
                        "destination": "ANY_IOS_SIMULATOR",
                        "scheme": scheme,
                        "platform": "IOS",
                        "isRequiredToPass": True,
                    },
                    {
                        "name": "Test",
                        "actionType": "TEST",
                        "destination": "ANY_IOS_SIMULATOR",
                        "scheme": scheme,
                        "platform": "IOS",
                        "isRequiredToPass": True,
                        "testConfiguration": {"kind": "USE_SCHEME_SETTINGS"},
                    },
                ],
                "pullRequestStartCondition": {
                    "source": {
                        "isAllMatch": False,
                        "patterns": [{"pattern": "*", "isPrefix": True}],
                    },
                    "destination": {
                        "isAllMatch": False,
                        "patterns": [{"pattern": dest_branch, "isPrefix": False}],
                    },
                    "autoCancel": True,
                },
                "manualBranchStartCondition": {
                    "source": {
                        "isAllMatch": False,
                        "patterns": [{"pattern": dest_branch, "isPrefix": False}],
                    }
                },
            },
            "relationships": {
                "product": {"data": {"type": "ciProducts", "id": product_id}},
                "repository": {"data": {"type": "scmRepositories", "id": repository_id}},
                "xcodeVersion": {"data": {"type": "ciXcodeVersions", "id": xcode_id}},
                "macOsVersion": {"data": {"type": "ciMacOsVersions", "id": macos_id}},
            },
        }
    }
    return asc_request(jwt, "POST", "/v1/ciWorkflows", body)


def main() -> int:
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    issuer = os.environ.get("ASC_ISSUER_ID", "").strip()
    if not key_id or not issuer:
        raise SystemExit("Set ASC_KEY_ID and ASC_ISSUER_ID")

    bundle_id = os.environ.get("ASC_BUNDLE_ID", "com.kadeem.twodo")
    workflow_name = os.environ.get("ASC_WORKFLOW_NAME", "PR Build & Test")
    scheme = os.environ.get("ASC_SCHEME", "TwoDo")
    container = os.environ.get("ASC_CONTAINER_PATH", "TwoDo.xcodeproj")
    owner = os.environ.get("ASC_REPO_OWNER", "kadeemj")
    repo_name = os.environ.get("ASC_REPO_NAME", "two-do")
    dest_branch = os.environ.get("ASC_DEST_BRANCH", "main")

    jwt = mint_jwt(key_id, issuer, load_key_pem())
    app = find_app(jwt, bundle_id)
    app_id = app["id"]
    app_name = (app.get("attributes") or {}).get("name")
    print(f"App: {app_name} ({app_id}) bundle={bundle_id}")

    product = find_product(jwt, app_id)
    repo = find_repo(jwt, owner, repo_name)

    missing = []
    if not product:
        missing.append(
            f"Enable Xcode Cloud for this app:\n"
            f"  https://appstoreconnect.apple.com/apps/{app_id}/ci\n"
            f"  → Get Started"
        )
    if not repo:
        missing.append(
            f"Grant Xcode Cloud GitHub access to {owner}/{repo_name} "
            f"(App Store Connect → Xcode Cloud → Manage Repositories / Create Workflow repository picker)."
        )
    if missing:
        print("\nBlocked — Apple requires these one-time steps (not available via API):\n")
        for i, msg in enumerate(missing, 1):
            print(f"{i}. {msg}\n")
        print("Re-run this script after those are done.")
        return 2

    assert product is not None and repo is not None
    print(f"Xcode Cloud product: {product['id']} ({(product.get('attributes') or {}).get('name')})")
    print(f"Repository: {owner}/{repo_name} ({repo['id']})")

    for wf in list_workflows(jwt, product["id"]):
        if (wf.get("attributes") or {}).get("name") == workflow_name:
            print(f"Workflow already exists: {workflow_name} ({wf['id']})")
            print(
                f"https://appstoreconnect.apple.com/apps/{app_id}/ci/workflows/{wf['id']}"
            )
            return 0

    xcode = latest_xcode(jwt)
    macos = compatible_macos(jwt, xcode["id"])
    print(
        f"Environment: Xcode {(xcode.get('attributes') or {}).get('version')} / "
        f"macOS {(macos.get('attributes') or {}).get('version')}"
    )

    created = create_workflow(
        jwt,
        product_id=product["id"],
        repository_id=repo["id"],
        xcode_id=xcode["id"],
        macos_id=macos["id"],
        name=workflow_name,
        scheme=scheme,
        container=container,
        dest_branch=dest_branch,
    )
    wf = created.get("data") or {}
    wf_id = wf.get("id")
    print(f"Created workflow: {workflow_name} ({wf_id})")
    print(f"https://appstoreconnect.apple.com/apps/{app_id}/ci/workflows/{wf_id}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as err:
        print(err, file=sys.stderr)
        raise SystemExit(1) from None
