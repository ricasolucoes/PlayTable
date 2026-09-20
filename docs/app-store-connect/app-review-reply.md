# Reply to Apple App Review

Use the current contents of
[`fastlane/metadata/review_information/notes.txt`](../../fastlane/metadata/review_information/notes.txt)
as the reply body and as the App Review Information Notes field. Before
submitting, append the physical-device recording reference produced by
[`physical-device-qa.md`](physical-device-qa.md).

The recording must be attached in App Store Connect before enabling
`IOS_SUBMIT_FOR_REVIEW=true`. The Fastlane lane refuses that submission when
`IOS_REVIEW_RECORDING_REFERENCE` is empty.
