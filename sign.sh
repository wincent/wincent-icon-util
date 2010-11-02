#!/bin/sh

if [ "$BUILD_STYLE" = 'Release' ]; then
  codesign -s wincent.com "$CODESIGNING_FOLDER_PATH"
fi
