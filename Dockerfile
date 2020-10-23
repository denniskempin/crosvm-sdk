# Copyright 2018 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

FROM debian:buster
LABEL description="Interactive shell for crosvm development"

ARG USER_ID
ARG GROUP_ID

################################################################################
# As root:
################################################################################

RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    curl \
    g++ \
    gcc \
    git \
    kmod \
    lcov \
    libcap-dev \
    libdbus-1-dev \
    libegl1-mesa-dev \
    libfdt-dev \
    libgl1-mesa-dev \
    libgles2-mesa-dev \
    libpciaccess-dev \
    libssl-dev \
    libtool \
    libusb-1.0-0-dev \
    libwayland-dev \
    make \
    nasm \
    meson \
    ninja-build \
    pkg-config \
    protobuf-compiler \
    python3 \
    python3-setuptools \
    sudo

# Used /scratch for building dependencies which are too new or don't exist on Debian stretch.
WORKDIR /scratch

# Commit shas of dependencies currently need to be manually upreved.
# TODO: Consider using repo for pulling chromiumos dependencies.
RUN export MESON_COMMIT=a1a8772034aef90e8d58230d8bcfce54ab27bf6a \
  export LIBEPOXY_COMMIT=34ecb908b044446226f4cf8829419664ae0ca544 \
  export TPM2_COMMIT=a9bc45bb7fafc65ea8a787894434d409f533b1f1 \
  export PLATFORM2_COMMIT=a386d01923b4d03e939560c09b326e5f38ec2ecc \
  export ADHD_COMMIT=932f912aa5a0c25c1d5806aa4ad9d8d4d4d98e84 \
  export DRM_COMMIT=00320d7d68ddc7d815d073bb7c92d9a1f9bb8c31 \
  export MINIJAIL_COMMIT=85d797ecbfd7aefbb9486afeaed3cf5f74858562 \
  export VIRGL_COMMIT=c5663614beb2f3604f54772ebbd097dd86ceed89


# Suppress warnings about detached HEAD, which will happen a lot and is meaningless in this context.
RUN git config --global advice.detachedHead false

# The libdrm-dev in distro can be too old to build minigbm,
# so we build it from upstream.
RUN git clone https://gitlab.freedesktop.org/mesa/drm.git/ \
    && cd drm \
    && git checkout $DRM_COMMIT \
    && meson build \
    && ninja -C build/ install

# The gbm used by upstream linux distros is not compatible with crosvm, which must use Chrome OS's
# minigbm.
RUN dpkg --force-depends -r libgbm1
RUN git clone https://chromium.googlesource.com/chromiumos/platform/minigbm \
    && cd minigbm \
    && sed 's/-Wall/-Wno-maybe-uninitialized/g' -i Makefile \
    && make install -j$(nproc)

# New libepoxy has EGL_KHR_DEBUG entry points needed by crosvm.
RUN git clone https://github.com/anholt/libepoxy.git \
    && cd libepoxy \
    && git checkout $LIBEPOXY_COMMIT \
    && mkdir build \
    && cd build \
    && meson \
    && ninja install

# Build against virglrenderer master
RUN git clone https://gitlab.freedesktop.org/virgl/virglrenderer.git \
    && cd virglrenderer \
    && git checkout $VIRGL_COMMIT \
    && mkdir build \
    && cd build \
    && meson \
    && ninja install

# Install libtpm2 so that tpm2-sys/build.rs does not try to build it in place in
# the read-only source directory.
RUN git clone https://chromium.googlesource.com/chromiumos/third_party/tpm2 \
    && cd tpm2 \
    && git checkout $TPM2_COMMIT \
    && make -j$(nproc) \
    && cp build/libtpm2.a /lib

# PUll down platform2 repositroy and install librendernodehost.
# Note that we clone the repository outside of /scratch not to be removed
# because crosvm depends on libvda.
ENV PLATFORM2_ROOT=/platform2
RUN git clone https://chromium.googlesource.com/chromiumos/platform2 $PLATFORM2_ROOT \
    && cd $PLATFORM2_ROOT \
    && git checkout $PLATFORM2_COMMIT

# Reduces image size and prevents accidentally using /scratch files
RUN rm -r /scratch /usr/bin/meson

# The manual installation of shared objects requires an ld.so.cache refresh.
RUN ldconfig

# Setup user 'docker' with same UID/GID as host user.
RUN addgroup --gid $GROUP_ID docker
RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID docker
RUN adduser docker sudo
RUN echo "ALL ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN mkdir /workspace
RUN chown docker:docker /workspace

################################################################################
# As user 'docker':
################################################################################

USER docker
WORKDIR /workspace

# Install Rustup
RUN curl -LO "https://static.rust-lang.org/rustup/archive/1.22.1/x86_64-unknown-linux-gnu/rustup-init" \
    && echo "49c96f3f74be82f4752b8bffcf81961dea5e6e94ce1ccba94435f12e871c3bdb *rustup-init" | sha256sum -c - \
    && chmod +x rustup-init \
    && ./rustup-init -y \
    && rm rustup-init

ENV PATH="/home/docker/.cargo/bin:${PATH}"
RUN rustup --version \
    && cargo --version \
    && rustc --version

RUN rustup toolchain install stable
RUN rustup toolchain install nightly

RUN cargo install grcov
RUN cargo install rust-covfix

ENV CROS_ROOT=/workspace
ENV THIRD_PARTY_ROOT=$CROS_ROOT/third_party
RUN mkdir -p $THIRD_PARTY_ROOT
ENV AOSP_EXTERNAL_ROOT=$CROS_ROOT/aosp/external
RUN mkdir -p $AOSP_EXTERNAL_ROOT
ENV PLATFORM_ROOT=$CROS_ROOT/platform
RUN mkdir -p $PLATFORM_ROOT

RUN git clone https://chromium.googlesource.com/chromiumos/platform2 $CROS_ROOT/platform2 \
    && cd $CROS_ROOT/platform2 \
    && git checkout $PLATFORM2_COMMIT

# minijail does not exist in upstream linux distros.
RUN git clone https://android.googlesource.com/platform/external/minijail $AOSP_EXTERNAL_ROOT/minijail \
    && cd $AOSP_EXTERNAL_ROOT/minijail \
    && git checkout $MINIJAIL_COMMIT

# Pull the cras library for audio access.
RUN git clone https://chromium.googlesource.com/chromiumos/third_party/adhd $THIRD_PARTY_ROOT/adhd \
    && cd $THIRD_PARTY_ROOT/adhd \
    && git checkout $ADHD_COMMIT

WORKDIR /workspace/platform/crosvm
