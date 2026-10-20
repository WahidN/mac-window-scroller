# Window Carousel

A macOS menu bar app that puts your windows side by side in one horizontal strip, so you can scroll through them with a three-finger swipe.

## Requirements

- macOS 14 or later
- Swift 6 (Xcode 16 or the matching command line tools)
- An "Apple Development" signing certificate in your keychain, used by `make app`
- A trackpad for scrolling

## Build and run

```sh
make run
```

This builds a release binary, wraps it in `build/WindowCarousel.app`, signs it and opens it. Use `make app` to build without opening.

On first launch macOS asks for Accessibility permission. The app needs it to move and resize other apps' windows. Grant it in System Settings > Privacy & Security > Accessibility. A rebuild keeps the permission, because the app is signed with the same certificate each time.

Run the tests with:

```sh
swift test
```

## Trackpad setup

macOS uses three-finger sideways swipes for "Swipe between full-screen applications" by default. Move that gesture to four fingers in System Settings > Trackpad > More Gestures, so the app can use three.

## Usage

| Action | What it does |
| --- | --- |
| `⌃⌥C` | Add the focused window to the chain, or remove it if it's already in it |
| `⌃⌥F` | Make the focused chained window full width, press again to restore its width |
| `⌃⌥←` / `⌃⌥→` | Move the focused chained window one place left or right in the chain |
| Three-finger swipe left or right | Scroll the strip |

- New windows get half the screen width and the full usable height, with 8 pt gaps
- Windows outside the view park just past the screen edge, out of sight
- Scrolling has momentum and a rubber band at both ends
- When the strip comes to rest, the most visible window gets focus and an orange border
- A mini-map at the bottom of the screen shows where you are while you scroll
- Resize a chained window by dragging its edge and its neighbours move along
- The menu bar menu lists the chain, shows the permission status and opens Settings (`⌘,`)
- Settings shows the version and has a 'Start at login' checkbox

The chain starts empty each time the app launches.

## How it works

- Windows are moved and resized through the Accessibility API (`AXUIElement`)
- Hotkeys are registered with Carbon's `RegisterEventHotKey`, so they work in any app
- Raw trackpad touches come from the private `MultitouchSupport` framework, loaded with `dlopen`. If it's missing, scrolling turns off and the rest of the app keeps working
- Start at login uses `SMAppService.mainApp`

## Project layout

- `Sources/WindowCarousel`: the app
- `Tests/WindowCarouselTests`: tests for the layout, scroll physics and mini-map math
- `Resources/Info.plist`: bundle info, `LSUIElement` hides the Dock icon
