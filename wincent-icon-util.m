//
//  wincent-icon-util.m
//  Created by Wincent Colaiuta on 26 July 2007.
//
//  Copyright 2007 Wincent Colaiuta.
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import <Foundation/Foundation.h>

//! Show usage information.
void usage(void)
{
    fprintf(stderr,
            //--------------------------------- 80 columns --------------------------------->|
            "Usage:\n"
            "  wincent-icon-util -icon input.icns -folder target_folder\n");
}

int main(int argc, const char * argv[])
{
    NSAutoreleasePool   *pool       = [[NSAutoreleasePool alloc] init];
    int                 exitStatus  = EXIT_FAILURE;
    OSErr               err;
    OSStatus            status;

    // process arguments
    NSUserDefaults      *defaults   = [NSUserDefaults standardUserDefaults];
    NSString            *icnsPath   = [defaults stringForKey:@"icon"];
    NSString            *folderPath = [defaults stringForKey:@"folder"];
    if (!icnsPath || !folderPath)
    {
        usage();
        goto bail;
    }

    // get ref for icns file
    const char *icnsFileSystemPath = [icnsPath fileSystemRepresentation];
    const FSRef icnsRef;
    status = FSPathMakeRef((const UInt8 *)icnsFileSystemPath, (FSRef *)&icnsRef, NULL);
    if (status != noErr)
    {
        fprintf(stderr, "error: FSPathMakeRef() returned %d for icns file \"%s\"\n", (int)status, icnsFileSystemPath);
        goto bail;
    }

    // read icns file
    Handle family;
    status = ReadIconFromFSRef(&icnsRef, (IconFamilyHandle *)&family);
    if (status != noErr)
    {
        fprintf(stderr, "error: ReadIconFromFSRef() returned %d for icns file \"%s\"\n", (int)status, icnsFileSystemPath);
        goto bail;
    }

    // get name of resource forks (most likely will be "RESOURCE_FORK")
    HFSUniStr255 resourceForkName;
    err = FSGetResourceForkName(&resourceForkName);
    if (err != noErr)
    {
        fprintf(stderr, "error: FSGetResourceForkName() returned %d\n", err);
        goto bail;
    }

    // get FSRef for folder
    const char *folderFileSystemPath = [folderPath fileSystemRepresentation];
    const FSRef parentFolderRef;
    Boolean isDirectory;
    status = FSPathMakeRef((const UInt8 *)folderFileSystemPath, (FSRef *)&parentFolderRef, &isDirectory);
    if (status != noErr)
    {
        fprintf(stderr, "error: FSPathMakeRef() returned %d for folder \"%s\"\n", (int)status, folderFileSystemPath);
        goto bail;
    }
    if (!isDirectory)
    {
        fprintf(stderr, "error: \"%s\" is not a directory\n", folderFileSystemPath);
        goto bail;
    }

    // create the resource file
    UniChar     iconFileName[] = { 'I', 'c', 'o', 'n', '\r' };
    FSRef       iconFileRef;
    err = FSCreateResourceFile(&parentFolderRef, sizeof(iconFileName) / sizeof(UniChar), iconFileName, kFSCatInfoNone, NULL,
                               resourceForkName.length, resourceForkName.unicode, &iconFileRef, NULL);
    if (err != noErr)
    {
        fprintf(stderr, "error: FSCreateResourceFile() returned %d\n", err);
        goto bail;
    }

    // open the resource file
    ResFileRefNum refNum;
    err = FSOpenResourceFile(&iconFileRef, resourceForkName.length, resourceForkName.unicode, fsWrPerm, &refNum);
    if (err != noErr)
    {
        fprintf(stderr, "error: FSOpenResourceFile() returned %d\n", err);
        goto bail;
    }

    // write it to the file
    AddResource(family, kIconFamilyType, kCustomIconResource, "\p");
    WriteResource(family);
    ReleaseResource(family);

    // make the icon file invisible, creator Finder, type icon
    FSCatalogInfo catalogInfo;
    err = FSGetCatalogInfo(&iconFileRef, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL);
    if (err != noErr)
    {
        fprintf(stderr, "error: FSGetCatalogInfo() returned %d\n", err);
        goto closeResFile;
    }
    FileInfo *fileInfo      = (FileInfo *)catalogInfo.finderInfo;
    fileInfo->finderFlags   |= kIsInvisible;
    fileInfo->fileCreator   = 'MACS';   // can't find good constant definitions for these anywhere
    fileInfo->fileType      = 'icon';   // can't find good constant definitions for these anywhere
    err = FSSetCatalogInfo(&iconFileRef, kFSCatInfoFinderInfo, &catalogInfo);
    if (err != noErr)
    {
        fprintf(stderr, "error: FSSetCatalogInfo() returned %d\n", err);
        goto closeResFile;
    }

    // set the custom icon attribute on the folder
    err = FSGetCatalogInfo(&parentFolderRef, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL);
    if (err != noErr)
    {
        fprintf(stderr, "error: FSGetCatalogInfo() returned %d\n", err);
        goto closeResFile;
    }
    FolderInfo *folderInfo = (FolderInfo *)catalogInfo.finderInfo;
    folderInfo->finderFlags |= kHasCustomIcon;
    folderInfo->finderFlags &= ~kHasBeenInited; // Finder.h: "make sure this bit is cleared for folders"
    err = FSSetCatalogInfo(&parentFolderRef, kFSCatInfoFinderInfo, &catalogInfo);
    if (err != noErr)
    {
        fprintf(stderr, "error: FSSetCatalogInfo() returned %d\n", err);
        goto closeResFile;
    }
    exitStatus = EXIT_SUCCESS;

closeResFile:
    CloseResFile(refNum);
bail:
    [pool drain];
    return exitStatus;
}

// TODO: factor out icon code into separate function so that it can be called for multiple folders at once
