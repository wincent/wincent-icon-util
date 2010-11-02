#!/bin/sh -e
# Copyright 2009 Wincent Colaiuta.

. "buildtools/Common.sh"

# print warning if current HEAD is not a signed/annotated tag
TAGGED=""

# for signed tags $HEAD will be "2.0" or similar
# for unsigned tags or untagged commits will be "2.0-5-g08867ea" or similar
HEAD=$(git describe)
for TAG in $(git tag)
do
  if [ $TAG = $HEAD ]; then
    TAGGED=$TAG
  fi
done
if [ -z "$TAGGED" ]; then
  warn "current HEAD is not tagged/annotated, but it should be for official releases"
  TAGGED=$HEAD
fi

# give installer package unique name prior to uploading
mv "$BUILT_PRODUCTS_DIR/WincentIconUtility.pkg" \
   "$BUILT_PRODUCTS_DIR/$PROJECT-$TAGGED.pkg"

# prep source archive
git archive $TAGGED > "$BUILT_PRODUCTS_DIR/$PROJECT-$TAGGED-src.tar"

# add submodules to archive
git ls-tree $TAGGED | grep '^160000 ' | \
while read mode type sha1 path
do
  rm -rf "$PROJECT_TEMP_DIR/$PROJECT-$TAGGED-$path-src/$path"
  mkdir -p "$PROJECT_TEMP_DIR/$PROJECT-$TAGGED-$path-src/$path"
  (cd $path && git archive $sha1 | tar -xf - -C "$PROJECT_TEMP_DIR/$PROJECT-$TAGGED-$path-src/$path")
  tar -rf "$BUILT_PRODUCTS_DIR/$PROJECT-$TAGGED-src.tar" \
       -C "$PROJECT_TEMP_DIR/$PROJECT-$TAGGED-$path-src" $path
done
bzip2 -f "$BUILT_PRODUCTS_DIR/$PROJECT-$TAGGED-src.tar"

# prep release notes
PREV_TAG=$($BUILDTOOLS_DIR/git-last-tag.sh)
test -n "$PREV_TAG" || die 'no value for PREV_TAG'

NOTES="$BUILT_PRODUCTS_DIR/$PROJECT-$TAGGED-release-notes.txt"
DETAILED_NOTES="$BUILT_PRODUCTS_DIR/$PROJECT-$TAGGED-detailed-release-notes.txt"
echo "Changes from $PREV_TAG to $TAGGED:" > $NOTES
echo "" >> $NOTES
git log --no-decorate --pretty=format:'    %s' $PREV_TAG..$TAGGED >> $NOTES

echo "Changes from $PREV_TAG to $TAGGED:" > $DETAILED_NOTES
echo "" >> $DETAILED_NOTES
git log --no-decorate $PREV_TAG..$TAGGED >> $DETAILED_NOTES

# append submodule notes
git ls-tree $TAGGED | grep '^160000 ' | \
while read mode type sha1 path
do
  LAST_REF=$(git ls-tree $PREV_TAG | grep '^160000 ' | grep $path | awk '{ print $3 }')
  SUBMODULE_NOTES=$(cd $path && git log --no-decorate --pretty=format:'    %s' $LAST_REF..$sha1)
  DETAILED_SUBMODULE_NOTES=$(cd $path && git log --no-decorate $LAST_REF..$sha1)
  if [ $(echo "$SUBMODULE_NOTES" | wc -l) -ne 1 ]; then
    echo "" >> $NOTES
    echo "" >> $NOTES
    echo "$path (submodule): " >> $NOTES
    echo "" >> $NOTES
    echo "$SUBMODULE_NOTES" >> $NOTES

    echo "" >> $DETAILED_NOTES
    echo "--------------------------------------------------------------------------------" >> $DETAILED_NOTES
    echo "" >> $DETAILED_NOTES
    echo "$path (submodule): " >> $DETAILED_NOTES
    echo "" >> $DETAILED_NOTES
    echo "$DETAILED_SUBMODULE_NOTES" >> $DETAILED_NOTES
  fi
done

# prep plaintext version of manpage
MANPAGE="wincent-icon-util.1"
man ./$MANPAGE | col -b > "$BUILT_PRODUCTS_DIR/$MANPAGE.txt"
