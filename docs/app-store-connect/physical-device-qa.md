# Physical-device QA and App Review recording

This checklist is a release gate for the build submitted to Apple. It cannot
be completed by the desktop Godot captures alone: the final pass must use the
same signed IPA/TestFlight build on physical iPhone and iPad hardware.

## Required evidence

- Device model(s) and iOS version, using the latest supported iOS available at
  test time.
- App version/build number from `scripts/ios_version.sh`.
- A recording that starts on the device Home Screen, launches PlayTable, and
  shows the normal user flow without editor, terminal, or debug overlays.
- The App Store Connect attachment/reference for that recording. Set it as the
  protected GitHub environment variable `IOS_REVIEW_RECORDING_REFERENCE` before
  running the release lane with `IOS_SUBMIT_FOR_REVIEW=true`.

## Test flow to record

1. Install the release build from TestFlight or the signed IPA. Start recording
   while the device is on the Home Screen, then tap the PlayTable icon.
2. From the main menu, open Board Games, launch Checkers, make at least one
   legal move, return to the menu, and open Card Games or another game.
3. Open Settings and show language, sound, and music controls. Switch language
   only if it does not interrupt the main flow; the app does not require a
   login.
4. On two physical devices, open Network, select Tic-Tac-Toe, host on one
   device and join from the other over the same Wi-Fi. Make one move from each
   side and leave the match. If the recording includes internet multiplayer,
   create/join a temporary room by code and verify that both players connect.
5. Repeat the launch and one solo game with the device offline. Confirm that
   the core catalog and game remain playable without an account or connection.

## QA assertions

- The app launches without a crash on every supported physical device tested.
- All 22 games open; at minimum, the recorded flow covers one board game, one
  card game, settings, and the network lobby.
- No registration, login, account deletion, UGC, reporting/blocking, ads, IAP,
  or paywall appears.
- The Local Network permission prompt appears only when the local multiplayer
  feature first needs it, and the explanatory text identifies PlayTable's
  Wi-Fi match feature.
- The app does not request camera, microphone, photo library, contacts,
  location, or tracking permissions.
- The two-device LAN match and, if advertised in the recording, the temporary
  internet room both complete without a crash.

Record the result, device identifiers, OS versions, and recording reference in
the release ticket before attaching the video and replying in App Store
Connect. Do not submit for review while the recording reference is empty.
