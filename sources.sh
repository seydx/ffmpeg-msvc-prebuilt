# Copyright (c) 2026 seydx
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# What the build compiles. FFmpeg comes from the jellyfin-ffmpeg fork, which carries
# the jellyfin patch series (debian/patches) and pins every dependency in its builder
# scripts (builder/scripts.d), so bumping JELLYFIN_COMMIT moves FFmpeg, the patches
# and the dependencies together. Read by fetch-sources.sh and build.sh.

JELLYFIN_REPO=https://github.com/seydx/jellyfin-ffmpeg.git
JELLYFIN_COMMIT=133f85c5f3192f7b472f9bd8a6e1306fe4d76814

# Jellyfin patches MSVC cannot build (GCC vectorization flags, GCC-only SIMD code)
PATCH_EXCLUDE="
0029-enable-gcc-vectorization-and-fix-cpuflags.patch
0053-add-simd-optimized-tonemapx-filter.patch
"

# <directory> <source> [<revision>], where <source> is one of
#   jellyfin:<script>[:2]  repository and commit of a builder script (2: its second one)
#   shaderc:<dependency>   repository and revision shaderc's DEPS file pins
#   <repository>           a dependency jellyfin does not build for Windows, at <revision>
SOURCES="
AMF                 jellyfin:50-amf.sh
Vulkan-Shim-Loader  jellyfin:47-vulkan/45-vulkan-loader.sh
vulkan-headers      jellyfin:47-vulkan/45-vulkan-headers.sh
shaderc             jellyfin:47-vulkan/50-shaderc.sh
glslang             shaderc:glslang
spirv-headers       shaderc:spirv-headers
spirv-tools         shaderc:spirv-tools
opencl-headers      jellyfin:45-opencl.sh
opencl-icd-loader   jellyfin:45-opencl.sh:2
nv-codec-headers    jellyfin:50-ffnvcodec.sh
libvpl              jellyfin:50-libvpl.sh
whisper.cpp         jellyfin:60-whisper.sh
zlib                jellyfin:20-zlib.sh
xz                  jellyfin:25-xz.sh
libxml2             jellyfin:25-libxml2.sh
freetype            jellyfin:25-freetype.sh
fribidi             jellyfin:25-fribidi.sh
harfbuzz            jellyfin:45-harfbuzz.sh
libass              jellyfin:50-libass.sh
dav1d               jellyfin:50-dav1d.sh
svt-av1             jellyfin:50-svtav1.sh
x264                jellyfin:50-x264.sh
x265_git            jellyfin:50-x265.sh
libvpx              jellyfin:50-libvpx.sh
libwebp             jellyfin:50-libwebp.sh
libjxl              jellyfin:50-libjxl.sh
zimg                jellyfin:50-zimg.sh
fdk-aac             jellyfin:50-fdk-aac-stripped.sh
opus                jellyfin:50-libopus.sh
libogg              jellyfin:25-libogg.sh
libvorbis           jellyfin:45-libvorbis.sh
lame                https://github.com/lameproject/lame.git                 1f5cc9487284d5950343aa5d4f70de433468070a
openexr             https://github.com/AcademySoftwareFoundation/openexr.git 55d1a1404cec5b4b187009d9f7fe55a5622ac4e5
win-iconv           https://github.com/win-iconv/win-iconv.git              82f00fbc1b1156530a0bbd003b93b3942743ed27
"
