# OpenRec Settings Schema v0.1

Settings are stored as JSON at:

```text
~/Library/Application Support/OpenRec/settings.json
```

Default payload:

```json
{
  "schemaVersion": 1,
  "recording": {
    "defaultMode": "display",
    "outputFormat": "mp4",
    "videoCodec": "h264",
    "qualityPreset": "standard",
    "frameRate": 30,
    "includeCursor": true,
    "microphoneDeviceID": null,
    "audioPreset": "standard",
    "globalHotkey": null
  }
}
```

Rules:

- Writes must be atomic.
- Invalid JSON is renamed to `settings.invalid.json`, then defaults are recreated.
- Recording history and recording file paths must not be stored.

