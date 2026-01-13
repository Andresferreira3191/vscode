#!/usr/bin/env bash
#
# StackCodeSy Production Web Server Launcher
# Serves pre-compiled VSCode web with production-ready server
#

if [[ "$OSTYPE" == "darwin"* ]]; then
	realpath() { [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"; }
	ROOT=$(dirname $(dirname $(realpath "$0")))
else
	ROOT=$(dirname $(dirname $(readlink -f $0)))
fi

cd $ROOT

# Use the node binary from build
NODE=$(node build/lib/node.js)
if [ ! -e $NODE ]; then
	# Load remote node if not present
	npm run gulp node
fi

NODE=$(node build/lib/node.js)

# Launch production server
exec $NODE ./scripts/code-web-prod.js "$@"
