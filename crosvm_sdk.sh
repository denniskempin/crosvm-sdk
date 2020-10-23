#!/bin/bash
# Copyright 2019 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

docker run \
    --rm \
    --privileged \
    -it \
    --volume /dev/log:/dev/log \
    --volume $(realpath .):/workspace/platform/crosvm:rw \
    crosvm_sdk \
    "$@"
