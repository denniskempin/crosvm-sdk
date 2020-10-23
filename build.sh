#!/bin/bash
# Copyright 2019 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x
cd "${0%/*}"
docker build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) -t crosvm_sdk .
