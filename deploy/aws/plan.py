"""Read-only AWS preflight. This command never creates or changes resources."""

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="worknet")
    parser.add_argument("--max-monthly-usd", type=float, default=12)
    args = parser.parse_args()
    cli = shutil.which("aws")
    if not cli and os.name == "nt":
        candidate = Path(os.environ["LOCALAPPDATA"]) / "Programs/Amazon/AWSCLIV2/aws.exe"
        if candidate.is_file():
            cli = str(candidate)
    if not cli:
        raise SystemExit("AWS CLI v2 is required. Reopen the terminal after installation.")

    def read(*command):
        env = os.environ.copy()
        env.update(PYTHONIOENCODING="utf-8", PYTHONUTF8="1", AWS_PAGER="")
        result = subprocess.run(
            [cli, *command, "--region", "us-east-2", "--profile", args.profile, "--output", "json", "--no-cli-pager"],
            capture_output=True, text=True, encoding="utf-8", env=env,
        )
        if result.returncode:
            raise SystemExit(f"AWS read-only check failed: {' '.join(command[:2])} (exit {result.returncode}). Check this profile privately with AWS CLI.")
        return json.loads(result.stdout)

    read("sts", "get-caller-identity")
    plan = read("freetier", "get-account-plan-state")
    if plan.get("accountPlanType") != "FREE":
        raise SystemExit("Expected the FREE plan. Stop and review AWS Settings; this script will not change it.")
    bundle = next((b for b in read("lightsail", "get-bundles")["bundles"] if b["bundleId"] == "small_3_0" and b["isActive"]), None)
    if not bundle or bundle["price"] > args.max_monthly_usd:
        raise SystemExit("The approved Linux bundle is unavailable or exceeds the monthly reference. Review before proceeding.")
    blueprints = read("lightsail", "get-blueprints")["blueprints"]
    if not any(b["blueprintId"] == "ubuntu_24_04" and b["isActive"] for b in blueprints):
        raise SystemExit("Ubuntu 24.04 is not currently available in us-east-2.")
    template = Path(__file__).with_name("lightsail.json").resolve()
    read("cloudformation", "validate-template", "--template-body", "file://" + str(template))
    instances = read("lightsail", "get-instances")["instances"]
    expiry = plan.get("accountPlanExpirationDate")
    if expiry:
        expiry = datetime.fromisoformat(expiry.replace("Z", "+00:00")).astimezone(timezone(timedelta(hours=-5))).isoformat()
    report = {
        "profile": args.profile, "region": "us-east-2", "plan": "FREE",
        "free_plan_expires_bogota": expiry,
        "proposed_bundle": bundle["bundleId"], "monthly_instance_usd": bundle["price"],
        "ram_gb": bundle["ramSizeInGb"], "disk_gb": bundle["diskSizeInGb"],
        "vcpus": bundle.get("cpuCount"), "included_transfer_gb": bundle.get("transferPerMonthInGb"),
        "existing_instance_count": len(instances),
        "template_sha256": hashlib.sha256(template.read_bytes()).hexdigest(),
        "template_validated_by_aws": True, "resources_created": False,
        "credit_balance": "Confirm current remaining shared credits in AWS Settings before creation",
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
