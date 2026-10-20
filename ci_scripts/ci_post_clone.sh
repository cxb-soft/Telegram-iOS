#!/bin/bash
# Xcode Cloud post-clone: install Bazel, generate config, generate project.
set -euo pipefail

echo "=== TG ci_post_clone start ==="
uname -a
xcodebuild -version

# 1) Install the pinned Bazel (versions.json: 9.2.0 with sha256)
BAZEL_VERSION="9.2.0"
BAZEL_SHA="dd466352a3e4d3581b8898740ee1ff208866ccbe25f8d367c5dcb950219587e6"
curl -fsSL -o /tmp/bazel "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-darwin-arm64"
echo "${BAZEL_SHA}  /tmp/bazel" | shasum -a 256 -c -
chmod +x /tmp/bazel
/tmp/bazel --version

# 2) Build configuration from template + env vars
CFG_DIR="$HOME/telegram-configuration"
mkdir -p "$CFG_DIR"
python3 - <<PY
import json, os
cfg = {
    "bundle_id": os.environ.get("TG_BUNDLE_ID", "org.cxbsoft.TGClient"),
    "api_id": os.environ["TG_API_ID"],
    "api_hash": os.environ["TG_API_HASH"],
    "team_id": os.environ["TG_TEAM_ID"],
    "app_center_id": "0",
    "is_internal_build": "true",
    "is_appstore_build": "false",
    "appstore_id": "0",
    "app_specific_url_scheme": "tg",
    "premium_iap_product_id": "",
    "enable_siri": False,
    "enable_icloud": False,
}
with open(os.path.expanduser("~/telegram-configuration/configuration.json"), "w") as f:
    json.dump(cfg, f, indent=2)
print("config written:", {k: (v if "hash" not in k and k != "api_id" else "***") for k, v in cfg.items()})
PY

# 3) Generate the Xcode project (xcode-managed codesigning, no provisioning files needed)
cd "$CI_PRIMARY_REPOSITORY_PATH"
python3 build-system/Make/Make.py \
    --overrideXcodeVersion \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath="$HOME/telegram-configuration/configuration.json" \
    --xcodeManagedCodesigning

echo "=== TG ci_post_clone done ==="
