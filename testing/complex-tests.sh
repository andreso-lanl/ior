#!/bin/bash

# Test script for more complex IOR functionality testing various patterns
# You can override the defaults by setting the variables before invoking the script, or simply set them here...
# Example: export IOR_EXTRA="-v -v -v"

ROOT=${0%/*}
TYPE="advanced"

source $ROOT/test-lib.sh

#stonewalling tests
IOR 2 -a DUMMY -w -O stoneWallingStatusFile=stonewall.log -O stoneWallingWearOut=1 -D 1 -t 1000 -b 1000 -s 15 -k
IOR 2 -a DUMMY -r -O stoneWallingStatusFile=stonewall.log -D 1 -t 1000 -b 1000 -s 30 -k # max 15 still!
IOR 2 -a DUMMY -r -O stoneWallingStatusFile=stonewall.log -t 1000 -b 1000 -s 30 -k

MDTEST 2 -I 20 -a DUMMY -W 1 -x stonewall-md.log -C
MDTEST 2 -I 20 -a DUMMY -x stonewall-md.log -T -v
MDTEST 2 -I 20 -a DUMMY -x stonewall-md.log -D -v

#shared tests
IOR 2 -a POSIX -w -z -Y -e -i1 -m -t 100k -b 200k
IOR 2 -a POSIX -w -k -e -i1 -m -t 100k -b 200k
IOR 2 -a POSIX -r -z-k -e -i1 -m -t 100k -b 200k

#test mutually exclusive options
IOR 2 -a POSIX -w -z -k -e -i1 -m -t 100k -b 200k
IOR 2 -a POSIX -w -z -k -e -i1 -m -t 100k -b 200k
IOR 2 -a POSIX -w -Z -i1 -m -t 100k -b 100k -d 0.1

# Now set the num tasks per node to 1:
export IOR_FAKE_TASK_PER_NODES=1
IOR 2 -a POSIX -f $ROOT/bug-multi-node.conf

# Regression test: MPIIO file-per-process with unique per-rank directories (-F -u).
# MPIIO_Access() used to fall through to MPI_File_open() whenever stat() failed
# (i.e. the per-rank directory did not exist yet), instead of deferring to POSIX
# access() semantics the way it already did for a directory that does exist.
# PrependDir() uses access(F_OK) only to decide whether to mkdir() the per-rank
# directory, so on a fresh unique-dir root this made IOR abort with
# "ERROR: invalid directory permissions" even though POSIX worked fine for the
# identical scenario. Use a fresh root each run so the per-rank directories are
# guaranteed not to exist yet, exercising the exact failure path.
MPIIO_UNIQUE_DIR_ROOT="${IOR_TMP}/mpiio-unique-dir"
rm -rf "${MPIIO_UNIQUE_DIR_ROOT}"
mkdir -p "${MPIIO_UNIQUE_DIR_ROOT}"
IOR_TMP_SAVE="${IOR_TMP}"
IOR_TMP="${MPIIO_UNIQUE_DIR_ROOT}"
IOR 2 -a MPIIO -w -F -u -k -e -i1 -t 64k -b 64k
IOR_TMP="${IOR_TMP_SAVE}"

# Control: plain MPIIO file-per-process without -u must keep working unaffected.
IOR 2 -a MPIIO -w -F -k -e -i1 -t 64k -b 64k

END
