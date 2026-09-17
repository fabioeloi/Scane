# SCANE

A MacOS frontend for [SANE](http://www.sane-project.org).

This fork exposes active SANE advanced options instead of hiding them, including
device calibration, lamp, warmup, gain/offset, source, depth, geometry, and
backend-specific controls. Options are grouped by function and can be reset to
their backend defaults. Scanner profiles are persisted locally by option name,
and the scan result view supports TIFF, PNG, and JPEG output. Batch scanning is
available for sequential page capture.

The fork deliberately reports only capabilities supplied by the SANE backend.
It does not claim true 48-bit capture, infrared dust removal, or multi-exposure
unless the connected backend explicitly exposes and supports those features.

### Building with Xcode 27

Open `Scane.xcodeproj` in Xcode or build the unsigned Debug app from Terminal:

```sh
xcodebuild -project Scane.xcodeproj \
  -scheme Scane \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build-final \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

The project targets macOS 12.0 or newer. The resulting app is
`build-final/Build/Products/Debug/Scane.app`.

Did Apple unceremoniously drop support for your scanner?  Did the manufacturer stop updating its own drivers?  Don't dump that old thing in the local watershed, Scane will let you continue using your beloved device for many years to come.  Maybe!

![Screenshot](./Docs/Screenshot.png)

## Requirements

You will need:

* A Mac with at least MacOS Catalina
* [A device supported by SANE](http://www.sane-project.org/sane-mfgs.html)
* Possibly, some amount of luck


## Known Issues

Scane was designed to make the simplest use case work well: a single scanner connected via USB.  To that end:
* Scane only works with a single connected device.  If you have multiple connected scanners, one will randomly be selected.
* Some SANE controls are backend-specific and may not be safe or useful on every scanner.
* Planar RGB devices don't yet work.  Which scanners are planar RGB devices?  I dunno!
* Scanners with indeterminate line length don't yet work.  I think this is mostly sheet-fed scanners.
* No SANE custom configuration can be specified.


File bugs and feature requests in the Issues page.


## Authors

Matt Adam


## License

The Scane frontend is MIT-licensed.
The Sane backend is (generally) GPL-licensed, the license is viewable [here](https://gitlab.com/sane-project/backends/-/blob/master/LICENSE).
