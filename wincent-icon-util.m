// wincent-icon-util.m
//
// Copyright 2007-2010 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// system headers
#import <objc/objc-auto.h>

#pragma mark -
#pragma mark Embedded information for what(1)

#import "wincent-icon-util-version.h"

WO_SET_RCSID_STRING("Wincent Icon Utility", productname);
WO_SET_RCSID_STRING("Version: " WO_MARKETING_VERSION, version);
WO_SET_RCSID_STRING(WO_COPYRIGHT, copyright);

#pragma mark -
#pragma mark Functions

//! Show usage information.
void usage(const char *argv0)
{
    fprintf(stderr,
            //--------------------------------- 80 columns --------------------------------->|
            "%s\n"                                              // product name
            "https://wincent.com/products/icon-util\n"
            "%s\n"                                              // version
            "%s\n"                                              // copyright
            "\n"
            "Usage:\n"
            "  %s --icon input.icns --folder target_folder\n",
            WO_GET_RCSID_STRING(productname),
            WO_GET_RCSID_STRING(version),
            WO_GET_RCSID_STRING(copyright),
            argv0);
}

int main(int argc, const char * argv[])
{
    objc_startCollectorThread();
    NSAutoreleasePool   *pool       = [[NSAutoreleasePool alloc] init];
    int                 exitStatus  = EXIT_FAILURE;
    OSErr               err;
    OSStatus            status;

    // process arguments: will accept both --icon/--folder and -icon/-folder for
    // backwards compatibility
    NSUserDefaults      *defaults   = [NSUserDefaults standardUserDefaults];
    NSString            *icnsPath   = [defaults stringForKey:@"-icon"];
    if (!icnsPath)      icnsPath    = [defaults stringForKey:@"icon"];
    NSString            *folderPath = [defaults stringForKey:@"-folder"];
    if (!folderPath)    folderPath  = [defaults stringForKey:@"folder"];
    if (!icnsPath || !folderPath)
    {
        usage(argv[0]);
        goto bail;
    }

    // get ref for icns file
    const char *icnsFileSystemPath = [icnsPath fileSystemRepresentation];
    const FSRef icnsRef;
    status = FSPathMakeRef((const UInt8 *)icnsFileSystemPath, (FSRef *)&icnsRef, NULL);
    if (status != noErr)
    {
        fprintf(stderr, "error: FSPathMakeRef() returned %d for file \"%s\"\n", (int)status, icnsFileSystemPath);
        goto bail;
    }

    // read icns file
    Handle family;
    status = ReadIconFromFSRef(&icnsRef, (IconFamilyHandle *)&family);
    if (status != noErr)
    {
        fprintf(stderr, "error: ReadIconFromFSRef() returned %d for file \"%s\"\n", (int)status, icnsFileSystemPath);
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
    if (err == dupFNErr)
    {
        // file already exists; prepare to try to open it
        const char *iconFileSystemPath = [[folderPath stringByAppendingPathComponent:@"Icon\r"] fileSystemRepresentation];
        status = FSPathMakeRef((const UInt8 *)iconFileSystemPath, &iconFileRef, NULL);
        if (status != noErr)
        {
            fprintf(stderr, "error: FSPathMakeRef() returned %d for file \"%s\"\n", (int)status, iconFileSystemPath);
            goto bail;
        }
    }
    else if (err != noErr)
    {
        fprintf(stderr, "error: FSCreateResourceFile() returned %d\n", err);
        goto bail;
    }

    // open the resource file
    ResFileRefNum refNum;
    err = FSOpenResourceFile(&iconFileRef, resourceForkName.length, resourceForkName.unicode, fsRdWrPerm, &refNum);
    if (err != noErr)
    {
        fprintf(stderr, "error: FSOpenResourceFile() returned %d\n", err);
        goto bail;
    }

    // delete any pre-existing icon resources
    short iconFamilyCount = Count1Resources(kIconFamilyType);
    if (ResError() == noErr)
    {
        Handle handle;
        for (short i = 1; i <= iconFamilyCount; i++)
        {
            handle = Get1IndResource(kIconFamilyType, i);
            if (handle)
                RemoveResource(handle);
        }
    }

    // write new resource to the file
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
