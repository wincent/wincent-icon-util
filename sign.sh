#!/bin/sh

if [ "$BUILD_STYLE" = 'Release' -a "$USER" = 'wincent' ]; then
  codesign -v "$CODESIGNING_FOLDER_PATH" 2> /dev/null ||
    codesign -s wincent.com "$CODESIGNING_FOLDER_PATH"
fi
