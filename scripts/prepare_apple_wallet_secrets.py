#!/usr/bin/env python3
"""Convert a Keychain-exported .p12 into a private Supabase secrets env file.

The password and private key are never printed. Delete the generated file after
uploading it to Supabase Edge Function Secrets.
"""

import argparse
import base64
import getpass
import os
from pathlib import Path
import re
import subprocess
import tempfile


def extract_pem(p12: Path, password: str, option: str, label: str) -> bytes:
    command = [
        "openssl", "pkcs12", "-in", str(p12), option,
        "-passin", "stdin",
    ]
    if option == "-nocerts":
        command.append("-nodes")
    else:
        command.append("-nokeys")
    def run(args: list[str]) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run(
            args,
            input=(password + "\n").encode(),
            capture_output=True,
            check=False,
        )

    result = run(command)
    if result.returncode:
        result = run(command + ["-legacy"])
    if result.returncode:
        raise SystemExit("Could not read the .p12 file. Check its password and try again.")
    pem_label = rb"(?:RSA |EC )?PRIVATE KEY" if label == "PRIVATE KEY" else label.encode()
    match = re.search(
        rb"-----BEGIN (" + pem_label + rb")-----\s+.*?-----END \1-----",
        result.stdout,
        re.DOTALL,
    )
    if match is None:
        raise SystemExit(f"The .p12 file contains no {label.lower()}.")
    return match.group(0) + b"\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("p12", type=Path, help="Path to the exported .p12 file")
    args = parser.parse_args()
    if not args.p12.is_file():
        raise SystemExit("The .p12 file was not found.")
    password = getpass.getpass(".p12 export password: ")
    cert = extract_pem(args.p12, password, "-clcerts", "CERTIFICATE")
    key = extract_pem(args.p12, password, "-nocerts", "PRIVATE KEY")
    fd, filename = tempfile.mkstemp(prefix="clupup-wallet-secrets-", suffix=".env")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as target:
            target.write("APPLE_WALLET_PASS_TYPE_ID=pass.com.3mb.clupup.events\n")
            target.write("APPLE_WALLET_TEAM_ID=BPNS3G27Y8\n")
            target.write("APPLE_WALLET_SIGNER_CERT_B64=" + base64.b64encode(cert).decode() + "\n")
            target.write("APPLE_WALLET_SIGNER_KEY_B64=" + base64.b64encode(key).decode() + "\n")
    except BaseException:
        Path(filename).unlink(missing_ok=True)
        raise
    print(f"Secrets file created at {filename}")
    print("Upload it with `supabase secrets set --env-file <path>` or the Supabase Dashboard, then delete it.")


if __name__ == "__main__":
    main()
