# crosvm-sdk

Docker-based build environment for crosvm. Based on the same docker container
that runs smoke tests in the CQ.

Usage:

```
$ ./build.sh
$ export PATH=$(pwd):$PATH
```

Then just prefix build commands with crosvm_sdk to run them inside the docker
container. Output files are written to the usual ./target dir.

```
$ crosvm_sdk cargo build
$ crosvm_sdk ./bin/smoke_test
```
