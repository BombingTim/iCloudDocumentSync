//
//  iCloudDocument_OSX.h
//  iCloud
//
//  Created by Tim on 7/18/14.
//  Copyright (c) 2014 iRare Media. All rights reserved.
//


// Check for Objective-C Modules
#if __has_feature(objc_modules)
    // We recommend enabling Objective-C Modules in your project Build Settings for numerous benefits over regular #imports. Read more from the Modules documentation: http://clang.llvm.org/docs/Modules.html
    @import Foundation;
    @import Cocoa;
#else
    #import <Foundation/Foundation.h>
   #import <Cocoa/Cocoa.h>
#endif

typedef NS_OPTIONS(NSUInteger, iCloudDocumentState) {
    iCloudDocumentStateNormal          = 0,
    iCloudDocumentStateClosed          = 1 << 0, // The document has either not been successfully opened, or has been since closed. Document properties may not be valid.
    iCloudDocumentStateInConflict      = 1 << 1, // Conflicts exist for the document's fileURL. They can be accessed through +[NSFileVersion otherVersionsOfItemAtURL:].
    iCloudDocumentStateSavingError     = 1 << 2, // An error has occurred that prevents the document from saving.
    iCloudDocumentStateEditingDisabled = 1 << 3  // Set before calling -disableEditing. The document is is busy and it is not currently safe to allow user edits. -enableEditing will be called when it becomes safe to edit again.
};

#define iCloudFileType @"iCloud"
/** Use the iCloudDocument class (a subclass of UIDocument) to read and write documents managed by the iCloud class. You should rarely interact directly with iCloudDocument. The iCloud class manages all interactions with iCloudDocument. You can however retieve an iCloudDocument object by specifying its URL in the iCloud class.
 
 iCloudDocument can read and write any files with the following exceptions:
 
 - Bundles
 - Packages
 - Aliases
 
 If you'd like support for the above faux files then please consider [filing an Issue on GitHub](https://github.com/iRareMedia/iCloudDocumentSync/issues/new) or [submitting a Pull Request](https://github.com/iRareMedia/iCloudDocumentSync/pulls) if you've figured out how. This can be done using an NSFileWrapper. 
 
 You may want to consider subclassing iCloudDocument for custom implementations of many features. */
@class iCloudDocument_OSX;
@protocol iCloudDocumentDelegate;

@interface iCloudDocument_OSX : NSDocument

@property (nonatomic,strong) NSData *contents;

/** @name Methods */

/** Initialize a new UIDocument with the specified file path
 
 @param url	The path to the UIDocument file
 @return UIDocument object at the specified URL */

@end