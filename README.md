# B11 Departures

A macOS desktop widget showing the next B11 boats from Lysaker brygge to Nesoddtangen, using live data from [Entur](https://developer.entur.org/).

- Countdown to each sailing, with live/scheduled status and delays
- Cancelled sailings are struck through, and the small widget skips them
- Ruter disruption messages appear as a yellow line under the header
- Small, medium and large sizes

## Install

Requires macOS 14 or later and Xcode.

```bash
git clone https://github.com/HarNys/B11Widget.git
cd B11Widget
bash install.sh
```

Then right-click the desktop → **Edit Widgets…**, search for **B11** and add it.

To update later, `git pull` and run `bash install.sh` again. If the widget still shows the old version, remove it and add it again.

## Notes

- The app is ad-hoc signed ("Sign to Run Locally"), so no Apple developer account is needed.
- macOS decides when widgets refresh. Departures are fetched about every 10 minutes, and the countdown updates every minute in between.
- Stop and line are fixed in `B11WidgetExtension/Entur.swift` (`stopPlaceId`, `lineId`). Per-widget configuration would need the app signed with a real Apple team, because macOS won't store widget settings for ad-hoc signed apps.
