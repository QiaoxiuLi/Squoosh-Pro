# Third-Party Notices

Squoosh Pro is an independent application. It is not an official Google product and does not receive endorsement from Google by using open-source Squoosh code.

The bundled codec JavaScript and WebAssembly artifacts were copied without source modification from `GoogleChromeLabs/squoosh` commit `e8d35e0fb66eb16eff6fe8fc773eabcbb7128de3`:

- Squoosh integration and generated glue: Apache License 2.0, see `LICENSES/SQUOOSH-APACHE-2.0.txt`
- MozJPEG/libjpeg-turbo: compatible BSD-style and IJG licenses, see `LICENSES/MOZJPEG.txt`
- OxiPNG: MIT License, see `LICENSES/OXIPNG.txt`
- WebP/libwebp: BSD-style license, see `LICENSES/WEBP.txt`
- libavif: BSD 2-Clause license, see `LICENSES/LIBAVIF.txt`
- libaom AV1 codec: BSD 3-Clause license, see `LICENSES/LIBAOM.txt`

Source provenance is recorded in `UPSTREAM_COMMIT`. Vendored artifacts remain under their original licenses; the repository's MIT License applies only to original Squoosh Pro code and documentation.

The Windows x64 application additionally redistributes:

- Magick.NET-Q8-x64 and Magick.NET.Core 14.17.1: Apache License 2.0, see `LICENSES/MAGICK.NET-APACHE-2.0.txt`
- ImageMagick native components included by Magick.NET: ImageMagick License, see `LICENSES/IMAGEMAGICK.txt`
- Microsoft Windows App SDK 1.6.250602001 runtime components: Microsoft Software License Terms supplied with the NuGet package, see `LICENSES/WINDOWS_APP_SDK.txt`

The Windows release also contains .NET and Windows SDK runtime components under their respective Microsoft license terms. No third-party trademark is used to imply endorsement of Squoosh Pro.
