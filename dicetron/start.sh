#!/usr/bin/env sh
set -eu

# because -u is set, this script will fail if they are not defined
_test=$DISCORD_TOKEN
_test=$APP_ID
_test=$PUBLIC_KEY
_test=$DD_DICE_PATH
unset _test

npm run register
node src/app.js
