# OpenRec Error Model v0.1

Core returns structured `OpenRecError` values. App code maps these to UI.

| Error | UI Behavior |
| --- | --- |
| `permissionDenied(kind)` | Show permissions screen and re-check action. |
| `captureSourceUnavailable(source)` | Ask user to reselect display/window. |
| `captureConfigurationInvalid(reason)` | Block start and show configuration issue. |
| `microphoneUnavailable(deviceID)` | Fall back when possible or require microphone selection. |
| `hotkeyConflict` | Reject new hotkey and keep previous value. |
| `writerInitializationFailed(reason)` | Block recording start. |
| `writerFailed(reason)` | Stop capture and clean temp file. |
| `saveCancelled(path)` | Offer retry save or discard. |
| `unknown(reason)` | Show generic recoverable error. |

