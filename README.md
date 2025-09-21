# FFmpeg GitHub Action Builds (MSVC)

This repository provides **FFmpeg builds** compiled with **MSVC (Microsoft Visual C++)**, leveraging GitHub Actions to automate the process. Each release includes complete precompiled binaries, libraries, and development files, optimized for various platforms and configurations.

[![Build FFmpeg](https://github.com/System233/ffmpeg-builds/actions/workflows/build.yml/badge.svg?event=push)](https://github.com/System233/ffmpeg-builds/actions/workflows/build.yml)

## Contents of the Release Packages

Each release provides the following for all build variants, architectures, and licenses:

1. **Precompiled binaries** (`ffmpeg`, `ffprobe`).
2. **Static libraries** for FFmpeg and included dependencies.
3. **Header files** for development.
4. **pkg-config (.pc) files** for library integration.
5. **CMake configuration files** for easy integration with CMake-based projects.
6. **SHA1 checksum files** for verifying integrity.

The files are packaged into **.zip** archives for each configuration, making it easy to download and integrate into your workflow.

## Downloading and Using the Builds

1. Visit the **[Releases](https://github.com/System233/ffmpeg-msvc-prebuilt/releases)** section.
2. Download the `.zip` archive and its corresponding `.sha1` checksum file for your desired configuration.
3. Verify the archive integrity using the `.sha1` checksum file.
   ```sh
   sha1sum -c <filename>.sha1
   ```
4. Extract the archive to access binaries, libraries, and development files.

## Features

### Built with MSVC

- Ensures compatibility with Windows development environments.
- Generates high-performance binaries optimized for modern Windows platforms.

### Build Variant

- **Static**: Fully self-contained binaries for standalone usage.

### Supported Architectures

- **amd64** (x86_64)
- **arm64** (aarch64)

### License

- **GPL Build**: Includes all components including **x264**, **x265**, and **fdk-aac** encoders.

### Included Dependencies

#### Video Codecs
- [x264](https://code.videolan.org/videolan/x264.git) - H.264 encoder
- [x265](https://bitbucket.org/multicoreware/x265_git.git) - HEVC/H.265 encoder
- [libvpx](https://github.com/webmproject/libvpx.git) - VP8/VP9 encoder/decoder
- [libdav1d](https://code.videolan.org/videolan/dav1d.git) - AV1 decoder
- [libsvtav1](https://gitlab.com/AOMediaCodec/SVT-AV1.git) - AV1 encoder

#### Audio Codecs
- [libmp3lame](https://github.com/lame-mirror/lame.git) - MP3 encoder
- [libfdk-aac](https://github.com/mstorsjo/fdk-aac.git) - AAC encoder
- [libopus](https://github.com/xiph/opus.git) - Opus encoder/decoder
- [libvorbis](https://github.com/xiph/vorbis.git) - Vorbis encoder/decoder
  - [libogg](https://github.com/xiph/ogg.git)

#### Hardware Acceleration
- [nv-codec-headers](https://github.com/FFmpeg/nv-codec-headers.git) - NVIDIA CUDA/NVENC (x64 only)
- [AMF](https://github.com/GPUOpen-LibrariesAndSDKs/AMF.git) - AMD AMF (x64 only)
- [libvpl](https://github.com/intel/libvpl.git) - Intel QuickSync (x64 only)
- [opencl-headers](https://github.com/KhronosGroup/OpenCL-Headers.git) - OpenCL
- [opencl-icd-loader](https://github.com/KhronosGroup/OpenCL-ICD-Loader.git)

#### Image Processing
- [libjxl](https://github.com/libjxl/libjxl.git) - JPEG XL support
  - [openexr](https://github.com/AcademySoftwareFoundation/openexr.git)
- [libwebp](https://github.com/webmproject/libwebp.git) - WebP support
- [libzimg](https://github.com/sekrit-twc/zimg.git) - High-quality image scaling

#### Text/Subtitle Rendering
- [freetype](https://gitlab.freedesktop.org/freetype/freetype.git) - Font rendering
- [harfbuzz](https://github.com/harfbuzz/harfbuzz.git) - Text shaping
- [libass](https://github.com/libass/libass.git) - ASS/SSA subtitle rendering
  - [fribidi](https://github.com/fribidi/fribidi.git) - Bidirectional text

#### Other Libraries
- [zlib](https://github.com/madler/zlib.git) - Compression
- [xz](https://github.com/tukaani-project/xz.git) - LZMA/XZ compression


### Windows-specific Features

- **MediaFoundation** (ARM64 only)
- **DXVA2, D3D11VA, D3D12VA** - DirectX hardware acceleration
- **Schannel** - Windows native TLS/SSL

## License

- The scripts in this repository are licensed under the **MIT License**.
- The binaries are **GPL-licensed** due to included components like x264, x265, and fdk-aac.
