This release contains FFmpeg builds with Jellyfin patches, compiled with MSVC (Microsoft Visual C++) via GitHub Actions.

### Build Configuration

- **Build Type**: Static libraries only
- **Architectures**: amd64 (x64) and arm64
- **License**: GPL v3 (includes all codecs and features)
- **Patches**: Includes Jellyfin FFmpeg patches for enhanced media server functionality

### Included Codecs & Libraries

#### Video Codecs

- [x264](https://code.videolan.org/videolan/x264.git) - H.264 encoder
- [x265](https://bitbucket.org/multicoreware/x265_git.git) - HEVC/H.265 encoder
- [libvpx](https://github.com/webmproject/libvpx.git) - VP8/VP9 encoder/decoder
- [libdav1d](https://code.videolan.org/videolan/dav1d.git) - AV1 decoder
- [libsvtav1](https://gitlab.com/AOMediaCodec/SVT-AV1.git) - AV1 encoder

#### Audio Codecs

- [libmp3lame](https://github.com/lame-mirror/lame.git) - MP3 encoder (MSVC native build)
- [libfdk-aac](https://github.com/mstorsjo/fdk-aac.git) - AAC encoder
- [libopus](https://github.com/xiph/opus.git) - Opus encoder/decoder
- [libvorbis](https://github.com/xiph/vorbis.git) - Vorbis encoder/decoder

#### Hardware Acceleration

- **NVIDIA**: CUDA/NVENC/NVDEC support via [nv-codec-headers](https://github.com/FFmpeg/nv-codec-headers.git) (x64 only)
- **AMD**: AMF encoding via [AMF SDK](https://github.com/GPUOpen-LibrariesAndSDKs/AMF.git) (x64 only)
- **Intel**: QuickSync via [libvpl](https://github.com/intel/libvpl.git) (x64 only)
- **Vulkan SDK**: Cross-platform GPU compute and filtering (both x64 and ARM64)
  - [glslang](https://github.com/KhronosGroup/glslang.git) shader compiler for Vulkan filters
- **Windows**: DXVA2, D3D11VA, D3D12VA hardware decoding
- **OpenCL**: Cross-vendor GPU acceleration

#### AI/ML Features

- **Whisper.cpp**: OpenAI Whisper speech-to-text via [whisper.cpp](https://github.com/ggml-org/whisper.cpp.git) (x64 only)
  - Integrated with GGML backend for CPU, OpenCL, and Vulkan acceleration
  - Available through FFmpeg's `af_whisper` audio filter

#### Image Processing

- [libjxl](https://github.com/libjxl/libjxl.git) - JPEG XL support
- [libwebp](https://github.com/webmproject/libwebp.git) - WebP support
- [libzimg](https://github.com/sekrit-twc/zimg.git) - High-quality scaling (MSVC native build)

#### Text/Subtitle Rendering

- [freetype](https://gitlab.freedesktop.org/freetype/freetype.git) - Font rendering
- [harfbuzz](https://github.com/harfbuzz/harfbuzz.git) - Text shaping
- [libass](https://github.com/libass/libass.git) - ASS/SSA subtitle rendering
- [fribidi](https://github.com/fribidi/fribidi.git) - Bidirectional text support

#### Other Libraries

- [zlib](https://github.com/madler/zlib.git) - Compression
- [xz](https://github.com/tukaani-project/xz.git) - LZMA/XZ compression
- [win-iconv](https://github.com/win-iconv/win-iconv.git) - Character encoding conversion
- [libxml2](https://github.com/GNOME/libxml2.git) - XML parsing

#### Release Notes
