#!/bin/bash

set -eu

BASEDIR=$(dirname $(realpath ${BASH_SOURCE[0]}))
RELEASE=${BASEDIR}/release

pushd ${BASEDIR}/overrides/blobs
for blob in $(find . -type f); do
    blob_name=${blob#./}
    bosh add-blob ${blob} ${blob_name} --dir=${RELEASE}
done
popd