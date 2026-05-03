#!/usr/bin/env python

import math
import subprocess
import sys
from datetime import datetime

from astral import Observer
from astral.sun import elevation

LATITUDE = 37.8
LONGITUDE = -122.4

DAY_TEMPERATURE = 6500
NIGHT_TEMPERATURE = 1000
TWILIGHT_ELEVATION = 10.0

now = datetime.now().astimezone()
sun_elevation = elevation(Observer(LATITUDE, LONGITUDE), now)
clamped_elevation = max(-TWILIGHT_ELEVATION, min(TWILIGHT_ELEVATION, sun_elevation))
dayness = 0.5 + 0.5 * math.sin(
    (math.pi / 2.0) * (clamped_elevation / TWILIGHT_ELEVATION)
)
temperature = round(NIGHT_TEMPERATURE + dayness * (DAY_TEMPERATURE - NIGHT_TEMPERATURE))

result = subprocess.run(
    ["hyprctl", "hyprsunset", "temperature", str(temperature)],
    check=False,
    stderr=subprocess.PIPE,
    stdout=subprocess.PIPE,
    text=True,
)

if result.returncode == 0:
    print(f"Set temperature to {temperature}.")
else:
    message = result.stderr.strip() or result.stdout.strip()
    if message:
        print(message, file=sys.stderr)

sys.exit(result.returncode)
