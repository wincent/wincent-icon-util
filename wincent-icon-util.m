// wincent-icon-util.m
//
// Copyright 2007-2009 Wincent Colaiuta.
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

// system headers
#import <objc/objc-auto.h>

#pragma mark -
#pragma mark Embedded information for what(1)

// embed with tag
#define WO_TAGGED_RCSID(msg, tag) \
static const char *const rcsid_ ## tag[] __attribute__((used)) = { (char *)rcsid_ ## tag, "\100(#)" msg }

// use as string
#define WO_RCSID_STRING(tag) (rcsid_ ## tag[1] + 4)

WO_TAGGED_RCSID("Copyright 2007-2009 Wincent Colaiuta.", copyright);

#if defined(__i386__)
WO_TAGGED_RCSID("Architecture: Intel (i386)", architecture);
#elif defined(__x86_64__)
WO_TAGGED_RCSID("Architecture: Intel (x86_64)", architecture);
#endif

WO_TAGGED_RCSID("Version: 2.0.1", version);
WO_TAGGED_RCSID("wincent-icon-util", productname);

#pragma mark -
#pragma mark Functions

//! Show usage information.
void usage(void)
{
    fprintf(stderr,
            //--------------------------------- 80 columns --------------------------------->|
            "%s\n"                                              // product name
            "http://git.wincent.com/wincent-icon-util.git\n"
            "%s\n"                                              // version
            "%s\n"                                              // copyright
            "\n"
            "Usage:\n"
            "  %s -icon input.icns -folder target_folder\n",
            WO_RCSID_STRING(productname), WO_RCSID_STRING(version),
            WO_RCSID_STRING(copyright), WO_RCSID_STRING(productname));
}

int main(int argc, const char * argv[])
{
    objc_startCollectorThread();
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
