//
//  iCloud_OSX.h
//  iCloud OSX
//
//  Created by Tim on 7/18/14.
//  Copyright (c) 2014 iRare Media. All rights reserved.
//

// Check for Objective-C Modules
#if __has_feature(objc_modules)
    // We recommend enabling Objective-C Modules in your project Build Settings for numerous benefits over regular #imports. Read more from the Modules documentation: http://clang.llvm.org/docs/Modules.html
    @import Foundation;
#else
    #import <Foundation/Foundation.h>
#endif

// Import iCloudDocument
#import "iCloudDocument_OSX.h"


// Create a constant for accessing the documents directory
#define DOCUMENT_DIRECTORY @"Documents"


/** iCloud Document Sync makes it easy for developers to integrate the iCloud document storage APIs into iOS applications. This is how iCloud document-storage and management should've been out of the box from Apple. Integrate iCloud into iOS (OS X coming soon) Objective-C document projects with one-line code methods. Sync, upload, manage, and remove documents to and from iCloud with only a few lines of code (compared to the hundreds of lines and hours that it usually takes). Get iCloud up and running in your iOS app in only a few minutes. Updates and more details on this project can be found on [GitHub](http://www.github.com/iRareMedia/iCloudDocumentSync). If you like the project, please star it on GitHub!
 
 The `iCloud` class provides methods to integrate iCloud into document projects.
 
 Adding iCloud Document Sync to your project is easy. Follow these steps below to get everything up and running.
 
 1. Drag the iCloud Framework into your project
 2. Add `#import <iCloud/iCloud.h>` to your header file(s) iCloud Document Sync
 3. Subscribe to the `<iCloudDelegate>` delegate.
 4. Call the following methods to setup iCloud when your app starts:
 
    [[iCloud sharedCloud] setDelegate:self]; // Set this if you plan to use the delegate
    [[iCloud sharedCloud] setVerboseLogging:YES]; // We want detailed feedback about what's going on with iCloud, this is OFF by default
    [[iCloud sharedCloud] updateFiles]; // Force iCloud Update: This is done automatically when changes are made, but we want to make sure the view is always updated when presented
 
  */
@class iCloud_OSX;
@protocol iCloudDelegate;
@interface iCloud_OSX : NSObject


/** @name Singleton */

/** iCloud shared instance object
 @return The shared instance of iCloud */
+ (instancetype)sharedCloud;
+ (instancetype)sharedCloudWithAppId:(NSString *)appId;



/** @name Delegate */

/** iCloud Delegate helps call methods when document processes begin or end */
@property (weak, nonatomic) id <iCloudDelegate> delegate;




/** @name Properties */

/** The current NSMetadataQuery object */
@property (strong) NSMetadataQuery *query;

/** A list of iCloud files from the current query */
@property (strong) NSMutableArray *fileList;

/** A list of iCloud files from the previous query */
@property (strong) NSMutableArray *previousQueryResults;

/** Enable verbose logging for detailed feedback in the log. Turning this off only prints crucial log notes such as errors. */
@property BOOL verboseLogging;

/** Enable verbose availability logging for repeated feedback about iCloud availability in the log. Turning this off will prevent availability-related messages from being printed in the log. This property does not relate to the verboseLogging property. */
@property BOOL verboseAvailabilityLogging;


/** @name Checking for iCloud */

/** Check whether or not iCloud is available and that it can be accessed. Returns a boolean value.  
 
 @discussion You should always check if iCloud is available before performing any iCloud operations (every method checks to make sure iCloud is available before continuing). Additionally, you may want to check if your users want to opt-in to iCloud on a per-app basis (according to Apple's documentation, you should only ask the user once to opt-in to iCloud). The Return value could be **NO** (iCloud Unavailable) for one or more of the following reasons:
 
   - iCloud is turned off by the user
   - The entitlements profile, code signing identity, and/or provisioning profile is invalid
 
 This method uses the ubiquityIdentityToken to check if iCloud is available. The delegate method iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer: can be used to automatically detect changes in the availability of iCloud. A ubiquity token is passed in that method which lets you know if the iCloud account has changed.
 
 @return YES if iCloud is available. NO if iCloud is not available. */
- (BOOL)checkCloudAvailability;

/** Check that the current application's iCloud Ubiquity Container is available. Returns a boolean value.
 
 @discussion This method may not return immediately, depending on a number of factors. It is not necessary to call this method directly, although it may become useful in certain situations.
 
 @return YES if the iCloud ubiquity container is available. NO if the ubiquity container is not available. */
- (BOOL)checkCloudUbiquityContainer;

/** Retrieve the current application's ubiquitous root URL

 @return An NSURL with the root iCloud Ubiquitous URL for the current app. May return nil if iCloud is not properly setup or available. */
- (NSURL *)ubiquitousContainerURL;

/** Retrieve the current application's ubiquitous documents directory URL
 
 @return An NSURL with the iCloud ubiquitous documents directory URL for the current app. May return nil if iCloud is not properly setup or available. */
- (NSURL *)ubiquitousDocumentsDirectoryURL;

/** @name Syncing with iCloud */

/** Check for and update the list of files stored in your app's iCloud Documents Folder. This method is automatically called by iOS when there are changes to files in the iCloud Directory. The iCloudFilesDidChange:withNewFileNames: delegate method is triggered by this method. */
- (void)updateFiles;

/** @name Uploading to iCloud */

/** Create, save, and close a document in iCloud.
 
 @discussion First, iCloud Document Sync checks if the specified document exists. If the document exists it is saved and closed. If the document does not exist, it is created then closed.
 
 iCloud Document Sync uses UIDocument and NSData to store and manage files. All of the heavy lifting with NSData and UIDocument is handled for you. There's no need to actually create or manage any files, just give iCloud Document Sync your data, and the rest is done for you.
 
 To create a new document or save an existing one (close the document), use this method. Below is a code example of how to use it.
 
    [[iCloud sharedCloud] saveAndCloseDocumentWithName:@"Name.ext" withContent:[NSData data] completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            // Code here to use the UIDocument or NSData objects which have been passed with the completion handler
        }
    }];
 
 Documents can be created even if the user is not connected to the internet. The only case in which a document will not be created is when the user has disabled iCloud or if the current application is not setup for iCloud.
 
 @param documentName The name of the document being written to iCloud. This value must not be nil.
 @param content The data to write to the document
 @param handler Code block called when the document is successfully saved. The completion block passes UIDocument and NSData objects containing the saved document and it's contents in the form of NSData. The NSError object contains any error information if an error occurred, otherwise it will be nil. */
- (void)saveAndCloseDocumentWithName:(NSString *)documentName withContent:(NSData *)content completion:(void (^)(iCloudDocument_OSX *cloudDocument, NSData *documentData, NSError *error))handler __attribute__((nonnull));

/** @name Deleting iCloud Content */

/** Delete a document from iCloud.
 
 @discussion Permanently delete a document stored in iCloud. This will only affect copies of the specified file stored in iCloud, if there is a copy stored locally it will not be affected.
 
 @param documentName The name of the document to delete from iCloud. This value must not be nil.
 @param handler Code block called when a file is successfully deleted from iCloud. The NSError object contains any error information if an error occurred, otherwise it will be nil. */
- (void)deleteDocumentWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler __attribute__((nonnull (1)));


/** Get the size of a file stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @return The number of bytes in an unsigned long long. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable. */
- (NSNumber *)fileSize:(NSString *)documentName __attribute__((nonnull));

/** Get the last modified date of a file stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @return The date that the file was last modified. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable. */
- (NSDate *)fileModifiedDate:(NSString *)documentName __attribute__((nonnull));

/** Get the creation date of a file stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @return The date that the file was created. Returns nil if the file does not exist. May return a nil value if iCloud is unavailable. */
- (NSDate *)fileCreatedDate:(NSString *)documentName __attribute__((nonnull));

/** Get a list of files stored in iCloud
 
 @return NSArray with a list of all the files currently stored in your app's iCloud Documents directory. May return a nil value if iCloud is unavailable. */
- (NSArray *)getListOfCloudFiles;

/** @name iCloud Document State */

/** Get the current document state of a file stored in iCloud
 
 @param documentName The name of the file in iCloud. This value must not be nil.
 @param handler Completion handler that passes three parameters, an NSError, NSString and a UIDocumentState. The documentState parameter represents the document state that the specified file is currently in (may be nil if the file does not exist). The userReadableDocumentState parameter is an NSString which succinctly describes the current document state; if the file does not exist, a non-scary error will be displayed. The NSError parameter will contain a 404 error if the file does not exist. */
- (void)documentStateForFile:(NSString *)documentName completion:(void (^)(iCloudDocumentState *documentState, NSString *userReadableDocumentState, NSError *error))handler __attribute__((nonnull));

/** @name Retrieving iCloud Content and Info */

/** Open a UIDocument stored in iCloud. If the document does not exist, a new blank document will be created using the documentName provided. You can use the doesFileExistInCloud: method to check if a file exists before calling this method.
 
 @discussion This method will attempt to open the specified document. If the file does not exist, a blank one will be created. The completion handler is called when the file is opened or created (either successfully or not). The completion handler contains a UIDocument, NSData, and NSError all of which contain information about the opened document.
 
    [[iCloud sharedCloud] retrieveCloudDocumentWithName:@"docName.ext" completion:^(UIDocument *cloudDocument, NSData *documentData, NSError *error) {
        if (error == nil) {
            NSString *documentName = [cloudDocument.fileURL lastPathComponent];
            NSData *fileData = documentData;
        }
     }];
 
 @param documentName The name of the document in iCloud. This value must not be nil.
 @param handler Code block called when the document is successfully retrieved (opened or downloaded). The completion block passes UIDocument and NSData objects containing the opened document and it's contents in the form of NSData. If there is an error, the NSError object will have an error message (may be nil if there is no error). This value must not be nil. */
- (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(iCloudDocument_OSX *cloudDocument, NSData *documentData, NSError *error))handler __attribute__((nonnull));

/** Get the file contents for the specified file
 @param documentName The name of the document in iCloud. This value must not be nil.
 @param handler Code block called when the data is successfully retrieved (opened or downloaded). The completion block passes a NSData object it's contents in the form of NSData. If there is an error, the NSError object will have an error message (may be nil if there is no error). This value must not be nil. */

-(void)retrieveCloudDataWithName:(NSString *)documentName completion:(void (^)(NSData *documentData, NSError *error))handler __attribute__((nonnull));

/** Check if a file exists in iCloud
 
 @param documentName The name of the UIDocument in iCloud. This value must not be nil.
 @return BOOL value, YES if the file does exist in iCloud, NO if it does not. May return NO if iCloud is unavailable. */
- (BOOL)doesFileExistInCloud:(NSString *)documentName __attribute__((nonnull));

@end

@protocol iCloudDelegate <NSObject>
/** @name Optional Delegate Methods */

@optional

/** Called when the availability of iCloud changes
 
 @param cloudIsAvailable Boolean value that is YES if iCloud is available and NO if iCloud is not available 
 @param ubiquityToken An iCloud ubiquity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has been changed (ex. if the user logged out and then logged in with a different iCloud account). This object may be nil if iCloud is not available for any reason.
 @param ubiquityContainer The root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container is initialized. */
- (void)iCloudAvailabilityDidChangeToState:(BOOL)cloudIsAvailable withUbiquityToken:(id)ubiquityToken withUbiquityContainer:(NSURL *)ubiquityContainer;


/** Called when the iCloud initiaization process is finished and the iCloud is available
 
 @param cloudToken An iCloud ubiquity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has been changed (ex. if the user logged out and then logged in with a different iCloud account). This object may be nil if iCloud is not available for any reason.
 @param ubiquityContainer The root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container is initialized. */
- (void)iCloudDidFinishInitializingWitUbiquityToken:(id)cloudToken withUbiquityContainer:(NSURL *)ubiquityContainer;


/** Called before creating an iCloud Query filter. Specify the type of file to be queried. 
 
 @discussion If this delegate is not implemented or returns nil, all files stored in the documents directory will be queried.
 
 @return An NSString with one file extension formatted like this: @"txt" */
- (NSString *)iCloudQueryLimitedToFileExtension;


/** Called before an iCloud Query begins.
 @discussion This may be useful to display interface updates. */
- (void)iCloudFileUpdateDidBegin;


/** Called when an iCloud Query ends.
 @discussion This may be useful to display interface updates. */
- (void)iCloudFileUpdateDidEnd;


/** Tells the delegate that the files in iCloud have been modified
 
 @param files A list of the files now in the app's iCloud documents directory - each NSMetadataItem in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames A list of the file names (NSString) now in the app's iCloud documents directory */
- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames;


/** Sent to the delegate where there is a conflict between a local file and an iCloud file during an upload or download
 
 @discussion When both files have the same modification date and file content, iCloud Document Sync will not be able to automatically determine how to handle the conflict. As a result, this delegate method is called to pass the file information to the delegate which should be able to appropriately handle and resolve the conflict. The delegate should, if needed, present the user with a conflict resolution interface. iCloud Document Sync does not need to know the result of the attempted resolution, it will continue to upload all files which are not conflicting. 
 
 It is important to note that **this method may be called more than once in a very short period of time** - be prepared to handle the data appropriately.
 
 The delegate is only notified about conflicts during upload and download procedures with iCloud. This method does not monitor for document conflicts between documents which already exist in iCloud. There are other methods provided to you to detect document state and state changes / conflicts.
 
 @param cloudFile An NSDictionary with the cloud file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate.
 @param localFile An NSDictionary with the local file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate. */
- (void)iCloudFileConflictBetweenCloudFile:(NSDictionary *)cloudFile andLocalFile:(NSDictionary *)localFile;




@end