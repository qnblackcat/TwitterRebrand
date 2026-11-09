# TwitterRebrand

A jailbreak tweak that makes the X app (`com.atebits.Tweetie2`) look like Twitter again, without patching the IPA, based on [neofreebird](https://github.com/NeoFreeBird/app).

| Where | What changes |
|---|---|
| SpringBoard | App name becomes "Twitter" (Home Screen, app switcher); Home Screen icon is replaced |
| System launch screen | `splashboardd` shows the Twitter bird on blue instead of the X logo |
| In the app | The app's own splash is made identical to the launch screen, so the two blend; the vector glyphs (tab bar, navigation bar, ...) and the X logo are replaced with the Twitter versions |

Works with rootless and roothide jailbreaks, iOS 15 and later.

## Artwork is not included

This repository contains code only. The Twitter artwork is not shipped here, and it is not covered by the license below. You supply it yourself, in a folder named `assets/` at the root of the project (it is git-ignored):

```
assets/
  Glyphs/   one SVG per glyph, named like the app's glyphs (home_stroke.svg, ...)
  Icons/    PNG Home Screen icons; ProductionAppIcon.png is the default; xLogo.png is the bird used for the X logo
  Launch/   LaunchScreen.nib and LaunchStoryboardBackgroundImage.png (the bird, 272x222 px at 2x)
```

The layout is the one of the resource packs used by NeoFreeBird's `rebrand.sh --resource-pack`: `svgs/` becomes `Glyphs/`, `icons/` becomes `Icons/` and the launch screen nib goes in `Launch/`.

To keep the artwork somewhere else, pass `TR_ASSETS=/path/to/dir` to `make`. The build stops with a message if a folder is missing.

## Build

<details>
<summary>Build instructions</summary>

Build the package with roothide's fork of Theos. 

```sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide

```
A build with `TR_DEBUG=1` writes what the hooks do t `TwitterRebrand.log`: in the temporary directory of the Twitter app (`<data container>/tmp/`) and of SpringBoard (`/var/mobile/tmp/).

</details>

## NeoFreeBird (optional)

TwitterRebrand works on its own; NeoFreeBird is not required. Without it the Home Screen shows the default icon (`ProductionAppIcon`).

Choosing the icon needs [my fork of NeoFreeBird](https://github.com/qnblackcat/neofreebird-tweak); the upstream [NeoFreeBird](https://github.com/NeoFreeBird/app) does not have this feature. With the fork installed, its "Change app icon" screen lists the icons shipped in `Icons/`. It tells this tweak which one was picked with a Darwin notification (`com.qn.twitterrebrand.icon.<name>`), because a sandboxed app cannot change SpringBoard's icon itself. The choice is stored in the `com.qn.twitterrebrand` preference domain.

## Disclaimer

Not affiliated with, endorsed by or sponsored by X Corp. or Twitter, Inc. "Twitter", the bird and related marks belong to their owners. Use of the artwork is your own responsibility.

## License

The source code is under the [MIT License](LICENSE). The license does not cover any artwork you place in `assets/`.
