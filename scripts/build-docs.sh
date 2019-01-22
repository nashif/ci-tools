#!/bin/bash
set -x

TYPE=daily
RELEASE=latest
TMP_BRANCH=$(mktemp XXXXXXXXX)

while getopts "dr:" opt; do
	case $opt in
		d)
			echo "Building daily docs" >&2
			TYPE=daily
			RELEASE=latest
			;;
		r)
			echo "Building release docs" >&2
			TYPE=release
			RELEASE=$OPTARG
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;
	esac
done

if [ -n "$MAIN_REPO_STATE" ]; then
	cd ${MAIN_REPO_STATE}
fi

if [ "$TYPE" == "release" ]; then
	git checkout upstream/v${RELEASE}-branch -b v${RELEASE}-branch-local.${TMP_BRANCH}
	git clean -dxf
fi
pwd
source ./zephyr-env.sh
unset BUILDDIR

echo "- Building docs for ${RELEASE:-development tree} ..."

export ENV_VAR_BOARD_DIR=boards/*/*/
export ENV_VAR_ARCH=*
make DOC_TAG=${TYPE} htmldocs
if [ "$?" == "0" ]; then
	echo "- Uploading to AWS S3..."
	if [ "$RELEASE" == "latest" ]; then
		aws s3 sync --delete --quiet doc/_build/html s3://docs.zephyrproject.org/latest
	else
		DOC_RELEASE=${RELEASE}.0
		aws s3 sync --quiet doc/_build/html s3://docs.zephyrproject.org/${DOC_RELEASE}
	fi
	if [ -d doc/_build/doxygen/html ]; then
		aws s3 sync --delete  --quiet doc/_build/doxygen/html s3://docs.zephyrproject.org/apidoc/${RELEASE}
	fi
else
	echo "- Failed"
fi

echo "=> Done"
