#!/usr/bin/env python

import math
import os
import subprocess
import sys
from argparse import ArgumentParser
from datetime import datetime

from astral import Observer
from astral.sun import elevation

DAY_TEMPERATURE = 6000
NIGHT_TEMPERATURE = 3000
TWILIGHT_ELEVATION = 10.0
REQUIRED_ENVIRONMENT = [
    "CAELESTIA_SCHEME_NAME",
    "CAELESTIA_SCHEME_FLAVOUR",
    "CAELESTIA_SCHEME_VARIANT",
]

missing_environment = [name for name in REQUIRED_ENVIRONMENT if name not in os.environ]
if missing_environment:
    print(
        "Missing required environment variable(s): "
        + ", ".join(missing_environment),
        file=sys.stderr,
    )
    sys.exit(1)

CAELESTIA_SCHEME_NAME = os.environ["CAELESTIA_SCHEME_NAME"]
CAELESTIA_SCHEME_FLAVOUR = os.environ["CAELESTIA_SCHEME_FLAVOUR"]
CAELESTIA_SCHEME_VARIANT = os.environ["CAELESTIA_SCHEME_VARIANT"]


def parse_args():
    parser = ArgumentParser()
    parser.add_argument("--latitude", required=True, type=float)
    parser.add_argument("--longitude", required=True, type=float)
    return parser.parse_args()


def run(command):
    return subprocess.run(
        command,
        check=False,
        stderr=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
    )

args = parse_args()
now = datetime.now().astimezone()
sun_elevation = elevation(Observer(args.latitude, args.longitude), now)
clamped_elevation = max(-TWILIGHT_ELEVATION, min(TWILIGHT_ELEVATION, sun_elevation))
dayness = 0.5 + 0.5 * math.sin(
    (math.pi / 2.0) * (clamped_elevation / TWILIGHT_ELEVATION)
)
temperature = round(NIGHT_TEMPERATURE + dayness * (DAY_TEMPERATURE - NIGHT_TEMPERATURE))
mode = "dark"

result = run(["hyprctl", "hyprsunset", "temperature", str(temperature)])

if result.returncode != 0:
    message = result.stderr.strip() or result.stdout.strip()
    if message:
        print(message, file=sys.stderr)
    sys.exit(result.returncode)

scheme_result = run(
    [
        "caelestia",
        "scheme",
        "get",
        "--name",
        "--flavour",
        "--mode",
        "--variant",
    ]
)

current_scheme = scheme_result.stdout.splitlines()
target_scheme = [
    CAELESTIA_SCHEME_NAME,
    CAELESTIA_SCHEME_FLAVOUR,
    mode,
    CAELESTIA_SCHEME_VARIANT,
]

if scheme_result.returncode != 0 or current_scheme != target_scheme:
    scheme_result = run(
        [
            "caelestia",
            "scheme",
            "set",
            "--name",
            CAELESTIA_SCHEME_NAME,
            "--flavour",
            CAELESTIA_SCHEME_FLAVOUR,
            "--mode",
            mode,
            "--variant",
            CAELESTIA_SCHEME_VARIANT,
        ]
    )
    if scheme_result.returncode != 0:
        message = scheme_result.stderr.strip() or scheme_result.stdout.strip()
        if message:
            print(message, file=sys.stderr)
        sys.exit(scheme_result.returncode)

print(f"Set temperature to {temperature} and kept theme mode at {mode}.")

sys.exit(0)
