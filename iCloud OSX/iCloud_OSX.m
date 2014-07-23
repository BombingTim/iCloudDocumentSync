//
//  iCloud_OSX.m
//  iCloud OSX
//
//  Created by Tim on 7/18/14.
//  Copyright (c) 2014 iRare Media. All rights reserved.
//

#import "iCloud_OSX.h"
#import "iCloudDocument_OSX.h"

// Check for ARC
#if !__has_feature(objc_arc)
    // Add the -fobjc-arc flag to enable ARC for only these files, as described in the ARC documentation: http://clang.llvm.org/docs/AutomaticReferenceCounting.html
    #error iCloudDocumentSync is built with Objective-C ARC. You must enable ARC for iCloudDocumentSync.
#endif

@interface iCloud_OSX () {
   // UIBackgroundTaskIdentifier backgroundProcess;
    NSFileManager *fileManager;
    NSNotificationCenter *notificationCenter;
    NSString *fileExtension;
    NSURL *ubiquityContainer;
}

@property (atomic,strong) NSString *appId;
/// Setup and start the metadata query and related notifications
- (void)enumerateCloudDocuments;

/// Called by the NSMetadataQuery notifications to updateFiles
- (void)startUpdate:(NSMetadataQuery *)notification;

/// Perform a quick a straightforward iCloud check without logging - for internal use
- (BOOL)quickCloudCheck;

@end

@implementation iCloud_OSX

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Setup --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Setup

+ (instancetype)sharedCloud {
    return [self sharedCloudWithAppId:nil];
}
+ (instancetype)sharedCloudWithAppId:(NSString *)appId {
    static iCloud_OSX *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		
        sharedManager = [[self alloc] initWithAppId:appId];
    });
    return sharedManager;
}

- (instancetype)initWithAppId:(NSString *)appId {
    // Setup Starter Sync
    self = [super init];
	
    self.appId = appId;
    
    NSLog(@"[iCloud] Beginning Initialization for App ID: %@",appId);
	
    if (self) {
        // Setup the File Manager
        if (fileManager == nil) fileManager = [NSFileManager defaultManager];
        
        // Setup the Notification Center
        if (notificationCenter == nil) notificationCenter = [NSNotificationCenter defaultCenter];
        
        // Initialize file lists, results, and queries
        if (_fileList == nil) _fileList = [NSMutableArray array];
        if (_previousQueryResults == nil) _previousQueryResults = [NSMutableArray array];
        if (_query == nil) _query = [[NSMetadataQuery alloc] init];
        
        // Check the iCloud Ubiquity Container
        dispatch_async (dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
			ubiquityContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:self.appId];
			if (ubiquityContainer != nil) {
				// We can write to the ubiquity container
				
				dispatch_async (dispatch_get_main_queue (), ^(void) {
					// On the main thread, update UI and state as appropriate
					
					// Check iCloud Availability
					id cloudToken = [fileManager ubiquityIdentityToken];
					
					// Sync and Update Documents List
					[self enumerateCloudDocuments];
					
					// Subscribe to changes in iCloud availability (should run on main thread)
					[notificationCenter addObserver:self selector:@selector(checkCloudAvailability) name:NSUbiquityIdentityDidChangeNotification object:nil];
					
					if ([_delegate respondsToSelector:@selector(iCloudDidFinishInitializingWitUbiquityToken: withUbiquityContainer:)])
						[_delegate iCloudDidFinishInitializingWitUbiquityToken:cloudToken withUbiquityContainer:ubiquityContainer];
				});
                
                // Log the setup
                NSLog(@"[iCloud] Ubiquity Container created and ready");
			}
		});
		
    }
    
    // Log the setup
    NSLog(@"[iCloud] Initialized");
    
    return self;
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Basic --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Basic

- (BOOL)checkCloudAvailability {
    id cloudToken = [fileManager ubiquityIdentityToken];
    if (cloudToken) {
        if (self.verboseAvailabilityLogging == YES) NSLog(@"iCloud is available. Ubiquity URL: %@\nUbiquity Token: %@", ubiquityContainer, cloudToken);
        
        if ([self.delegate respondsToSelector:@selector(iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer:)])
            [self.delegate iCloudAvailabilityDidChangeToState:YES withUbiquityToken:cloudToken withUbiquityContainer:ubiquityContainer];
        
        return YES;
    } else {
        if (self.verboseAvailabilityLogging == YES)
            NSLog(@"iCloud is not available. iCloud may be unavailable for a number of reasons:\n• The device has not yet been configured with an iCloud account, or the Documents & Data option is disabled\n• Your app, %@, does not have properly configured entitlements\nGo to http://bit.ly/18HkxPp for more information on setting up iCloud", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]);
        else
            NSLog(@"iCloud unavailable");
        
        if ([self.delegate respondsToSelector:@selector(iCloudAvailabilityDidChangeToState:withUbiquityToken:withUbiquityContainer:)])
            [self.delegate iCloudAvailabilityDidChangeToState:NO withUbiquityToken:nil withUbiquityContainer:ubiquityContainer];
        
        return NO;
    }
}

- (BOOL)checkCloudUbiquityContainer {
	if (ubiquityContainer){
		return YES;
	} else {
		return NO;
	}
}

- (BOOL)quickCloudCheck {
    if ([fileManager ubiquityIdentityToken]) {
        return YES;
    } else {
        return NO;
    }
}

- (NSURL *)ubiquitousContainerURL {
    return ubiquityContainer;
}

- (NSURL *)ubiquitousDocumentsDirectoryURL {
    @try {
        // Use the instance variable here - no need to start the retrieval process again
        if (ubiquityContainer == nil) ubiquityContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:self.appId];
        NSURL *documentsDirectory = [ubiquityContainer URLByAppendingPathComponent:DOCUMENT_DIRECTORY];
        NSError *error;
        
        BOOL isDirectory = NO;
        BOOL isFile = [fileManager fileExistsAtPath:[documentsDirectory path] isDirectory:&isDirectory];
        
        if (isFile) {
            // It exists, check if it's a directory
            if (isDirectory == YES) {
                return documentsDirectory;
            } else {
                [fileManager removeItemAtPath:[documentsDirectory path] error:&error];
                [fileManager createDirectoryAtURL:documentsDirectory withIntermediateDirectories:YES attributes:nil error:&error];
                return documentsDirectory;
            }
        } else {
            [fileManager createDirectoryAtURL:documentsDirectory withIntermediateDirectories:YES attributes:nil error:&error];
            return documentsDirectory;
        }
        
        if (error) NSLog(@"[iCloud] POSSIBLY FATAL ERROR - Document directory creation error. This error may be fatal and should be recovered from. If the documents directory is not correctly created, this can cause iCloud to stop functioning properly (including exceptiosn being thrown). Error: %@", error);
        
        NSLog(@"Documents URL: %@", documentsDirectory);
        return documentsDirectory;
        
    } @catch (NSException *exception) {
        // This method seems to be a common spot for exceptions. In an effort to reduce crashes here, try / catch code has been added (until the bug is squashed).
        // The most common exception is on this line: [NSFileManager createDirectoryAtURL:withIntermediateDirectories:attributes:error:]: URL is nil
        NSLog(@"[iCloud] Caught fatal exception (see below). Exception in ubiquitousDocumentsDirectoryURL method of the iCloud Framework. You may need to create the Document directory manually. This may be a known issue, but please report it on GitHub anyway.\n%@", exception);
    }
}
//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Sync ---------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Sync

- (void)enumerateCloudDocuments {
    // Log document enumeration
    NSLog(@"[iCloud] Creating metadata query and notifications");
    
    // Request information from the delegate
    if ([self.delegate respondsToSelector:@selector(iCloudQueryLimitedToFileExtension)]) {
        NSString *fileExt = [self.delegate iCloudQueryLimitedToFileExtension];
        if (fileExt != nil || ![fileExt isEqualToString:@""]) fileExtension = fileExt;
        else fileExtension = @"*";
        
        // Log file extensiom
        NSLog(@"[iCloud] Document query filter has been set to %@", fileExtension);
    } else fileExtension = @"*";
    
    // Setup iCloud Metadata Query
	[self.query setSearchScopes:@[NSMetadataQueryUbiquitousDocumentsScope]];
	[self.query setPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%%K.pathExtension LIKE '%@'", fileExtension], NSMetadataItemFSNameKey]];
    
    // Notify the responder that an update has begun
	[notificationCenter addObserver:self selector:@selector(startUpdate:) name:NSMetadataQueryDidStartGatheringNotification object:self.query];
    
    // Notify the responder that the update has completed
	[notificationCenter addObserver:self selector:@selector(endUpdate:) name:NSMetadataQueryDidFinishGatheringNotification object:self.query];
    
	//Listen for any updates
	[notificationCenter addObserver:self selector:@selector(endUpdate:) name:NSMetadataQueryDidUpdateNotification object:self.query];
    
	// Start the query on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL startedQuery = [self.query startQuery];
        if (!startedQuery) {
            NSLog(@"[iCloud] Failed to start query.");
            return;
        } else NSLog(@"[iCloud] Query initialized successfully"); // Log file query success
    });
}
- (void)startUpdate:(NSMetadataQuery *)query {
    // Log file update
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Beginning file update with NSMetadataQuery");
    
    // Notify the delegate of the results on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(iCloudFileUpdateDidBegin)])
            [self.delegate iCloudFileUpdateDidBegin];
    });
}

- (void)endUpdate:(NSMetadataQuery *)query {
    // Get the updated files
    [self updateFiles];
    
    // Log query completion
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Finished file update with NSMetadataQuery");
}

- (void)updateFiles {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Initialize the discovered files and file names array
    NSMutableArray *discoveredFiles = [NSMutableArray array];
    NSMutableArray *names = [NSMutableArray array];
    
	// Enumerate through the results
	[self.query enumerateResultsUsingBlock:^(id result, NSUInteger idx, BOOL *stop) {
		// Grab the file URL
		NSURL *fileURL = [result valueForAttribute:NSMetadataItemURLKey];
		NSNumber *aBool = nil;
		
		// Exclude hidden files
		[fileURL getResourceValue:&aBool forKey:NSURLIsHiddenKey error:nil];
		if (aBool && ![aBool boolValue]) {
			// Add the file metadata and file names to arrays
			[discoveredFiles addObject:result];
			[names addObject:[result valueForAttribute:NSMetadataItemFSNameKey]];
		}
		
		if (self.query.resultCount-1 >= idx) {
			// Notify the delegate of the results on the main thread
			dispatch_async(dispatch_get_main_queue(), ^{
				if ([self.delegate respondsToSelector:@selector(iCloudFilesDidChange:withNewFileNames:)])
					[self.delegate iCloudFilesDidChange:discoveredFiles withNewFileNames:names];
			});
		}
	}];
    
    // Notify the delegate of the results on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(iCloudFileUpdateDidEnd)])
            [self.delegate iCloudFileUpdateDidEnd];
    });
}

- (NSNumber *)fileSize:(NSString *)documentName {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        unsigned long long fileSize = [[fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileSize];
        NSNumber *bytes = [NSNumber numberWithUnsignedLongLong:fileSize];
        return bytes;
    } else {
        // The document could not be found
        NSLog(@"[iCloud] File not found: %@", fileURL.absoluteString);
        
        return nil;
    }
}

- (NSDate *)fileModifiedDate:(NSString *)documentName {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        NSDate *fileModified = [[fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileModificationDate];
        return fileModified;
    } else {
        // The document could not be found
        NSLog(@"[iCloud] File not found: %@", documentName);
        
        return nil;
    }
}

- (NSDate *)fileCreatedDate:(NSString *)documentName {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        NSDate *fileModified = [[fileManager attributesOfItemAtPath:[fileURL path] error:nil] fileCreationDate];
        return fileModified;
    } else {
        return nil;
    }
}

- (BOOL)doesFileExistInCloud:(NSString *)documentName {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return NO;
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
        return YES;
    } else {
        return NO;
    }
    
}

- (NSArray *)getListOfCloudFiles {
    // Log retrieval
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Getting list of iCloud documents");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return nil;
    
    // Get the directory contents
    NSArray *directoryContent = [fileManager contentsOfDirectoryAtURL:[self ubiquitousDocumentsDirectoryURL] includingPropertiesForKeys:nil options:0 error:nil];
    
    // Log retrieval
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Retrieved list of iCloud documents");
    
    // Return the list of files
    return directoryContent;
}


-(NSString *)getDocumentStateDescription:(iCloudDocumentState)state {
	switch (state) {
  case iCloudDocumentStateNormal:
	return @"Document is open";
  case iCloudDocumentStateClosed:
	return @"Document is closed";
  case iCloudDocumentStateInConflict:
	return @"Document is  in conflict";
  case iCloudDocumentStateSavingError:
	return @"Document has save error";
  case iCloudDocumentStateEditingDisabled:
	return @"Document editing is disabled";
  default:
    break;
}
	return @"";
}
//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ State --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - State

- (void)documentStateForFile:(NSString *)documentName completion:(void (^)(iCloudDocumentState *documentState, NSString *userReadableDocumentState, NSError *error))handler {
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(nil, nil, error);
        
        return;
    }
    
    // Get the URL to get the file from
	NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Check if the file exists, and return
    if ([fileManager fileExistsAtPath:[fileURL path]]) {
		iCloudDocumentState state = iCloudDocumentStateClosed;
		NSArray *conflicts = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileURL];
		if((conflicts) && (conflicts.count > 0)) {
			state = iCloudDocumentStateInConflict;
		} else {
			NSDocument *document = [[NSDocumentController sharedDocumentController] documentForURL:fileURL];
			if(document)
				state = iCloudDocumentStateNormal; //document is open

		}
		
        handler(&state, [self getDocumentStateDescription:state], nil);
    } else {
        // The document could not be found
        NSLog(@"[iCloud] File not found: %@", documentName);
        NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, fileURL] code:404 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
        handler(nil, @"No document available", error);
        return;
    }
}

//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Read ---------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Read

- (void)retrieveCloudDocumentWithName:(NSString *)documentName completion:(void (^)(iCloudDocument_OSX *cloudDocument, NSData *documentData, NSError *error))handler {
    // Log Retrieval
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Retrieving iCloud document, %@", documentName);
    
    // Check for iCloud availability
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(nil, nil, error);
        
        return;
    }
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // If the file exists open it; otherwise, create it
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log opening
            if (self.verboseLogging == YES) NSLog(@"[iCloud] The document, %@, already exists and will be opened", documentName);
            
          	NSError *error = nil;
			iCloudDocument_OSX *document = [[iCloudDocument_OSX alloc] initWithContentsOfURL:fileURL ofType:iCloudFileType error:&error];
	
			if((document == nil) || (error != nil)) {
					NSLog(@"[iCloud] Error while retrieving document: %s", __PRETTY_FUNCTION__);
					
					// Pass data on to the completion handler on the main thread
					dispatch_async(dispatch_get_main_queue(), ^{
						
						handler(document, document.contents, error);
					});

			} else {
				//Check for conflicts
				NSArray *conflicts = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileURL];
				if((conflicts) && (conflicts.count > 0)) {
					  if (self.verboseLogging == YES) NSLog(@"[iCloud] Document in conflict. The document may not contain correct data. An error will be returned along with the other parameters in the completion handler.");
					
					// Create Error
					NSLog(@"[iCloud] Error while retrieving document, %@, because the document is in conflict", documentName);
					error = [NSError errorWithDomain:[NSString stringWithFormat:@"The iCloud document, %@, is in conflict. Please resolve this conflict before editing the document.", documentName] code:200 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
				}


				// Pass data on to the completion handler on the main thread
				dispatch_async(dispatch_get_main_queue(), ^{
					
					handler((iCloudDocument_OSX *)document, document.contents, error);
				});

			}
			
		} else {
            // Log creation
            if (self.verboseLogging == YES) NSLog(@"[iCloud] The document, %@, does not exist and will be created as an empty document", documentName);
            // Create the Document
			NSError *error = nil;
			iCloudDocument_OSX *document = [[iCloudDocument_OSX alloc] initWithType:iCloudFileType error:&error];
			document.contents = [@"" dataUsingEncoding:NSUTF8StringEncoding]; //Give the document something in the contents
			if(error == nil) {
				[document saveToURL:fileURL ofType:iCloudFileType forSaveOperation:NSSaveOperation completionHandler:^(NSError *errorOrNil) {
					 // Log save
					if (self.verboseLogging == YES) NSLog(@"[iCloud] Saved and opened the document");
                
					dispatch_async(dispatch_get_main_queue(), ^{
						handler(document, document.contents, nil);
					});

				}];
				
			}
			
        }
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while retrieving document: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

-(void)retrieveCloudDataWithName:(NSString *)documentName completion:(void (^)(NSData *documentData, NSError *error))handler __attribute__((nonnull)) {
    // Log Retrieval
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Retrieving iCloud document, %@", documentName);
    
    // Check for iCloud availability
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(nil, error);
        
        return;
    }
    
    @try {
        // Get the URL to get the file from
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // If the file exists open it; otherwise, create it
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log opening
            if (self.verboseLogging == YES) NSLog(@"[iCloud] The document, %@, already exists and will be opened", documentName);
            
			NSError *error = nil;
            // Create the UIDocument object from the URL
            iCloudDocument_OSX *document = [[iCloudDocument_OSX alloc] initWithContentsOfURL:fileURL ofType:iCloudFileType error:&error];
           
			if (self.verboseLogging == YES) NSLog(@"[iCloud] Document is closed and will be opened");
                
			if((document == nil) || (error != nil)) {
				NSLog(@"[iCloud] Error while retrieving document: %s", __PRETTY_FUNCTION__);
				
				// Pass data on to the completion handler on the main thread
				dispatch_async(dispatch_get_main_queue(), ^{
					
					handler(nil, error);
				});

			} else {
				//Check for conflicts
				NSArray *conflicts = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileURL];
				if((conflicts) && (conflicts.count > 0)) {
					  if (self.verboseLogging == YES) NSLog(@"[iCloud] Document in conflict. The document may not contain correct data. An error will be returned along with the other parameters in the completion handler.");
					
					// Create Error
					NSLog(@"[iCloud] Error while retrieving document, %@, because the document is in conflict", documentName);
					error = [NSError errorWithDomain:[NSString stringWithFormat:@"The iCloud document, %@, is in conflict. Please resolve this conflict before editing the document.", documentName] code:200 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
				}


				// Pass data on to the completion handler on the main thread
				dispatch_async(dispatch_get_main_queue(), ^{
					
					handler(document.contents, error);
				});

			}
            
        } else {
            // Log creation
            if (self.verboseLogging == YES) NSLog(@"[iCloud] The document, %@, does not exist and will be created as an empty document", documentName);
            
            // Create the UIDocument
			NSError *error = nil;
			iCloudDocument_OSX *document = [[iCloudDocument_OSX alloc] initWithType:iCloudFileType error:&error];
			document.contents = [@"" dataUsingEncoding:NSUTF8StringEncoding]; //Give the document something in the contents
			if(error == nil) {
				[document saveToURL:fileURL ofType:iCloudFileType forSaveOperation:NSSaveOperation completionHandler:^(NSError *errorOrNil) {
					 // Log save
					if (self.verboseLogging == YES) NSLog(@"[iCloud] Saved and opened the document");
                
					if(errorOrNil) {
						NSLog(@"[iCloud] Error while saving document, %@\n error: %@", documentName,errorOrNil);
					}
					dispatch_async(dispatch_get_main_queue(), ^{
						handler(document.contents, nil);
					});

				}];
				
			}

			
		}
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while retrieving document: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }

}
//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Write --------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Write

- (void)saveAndCloseDocumentWithName:(NSString *)documentName withContent:(NSData *)content completion:(void (^)(iCloudDocument_OSX *cloudDocument, NSData *documentData, NSError *error))handler {
    // Log save
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Beginning document save");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        NSError *error = [NSError errorWithDomain:@"The specified document name was empty / blank and could not be saved. Specify a document name next time." code:001 userInfo:nil];
        
        handler(nil, nil, error);
        
        return;
    }
    
    // Get the URL to save the new file to
    NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
    
    // Initialize a document with that path
	NSError *error = nil;
   iCloudDocument_OSX *document = [[iCloudDocument_OSX alloc] initWithType:iCloudFileType error:&error];
    if(error != nil) {
		NSLog(@"ERROR Creating iCloud Document in saveAndCloseDocumentWithName: %@", error.localizedDescription);
		handler(nil,nil,error);
		return;
	}
	
	document.contents = content;
   
	// The document did not exist and is being saved for the first time.
		
	if (self.verboseLogging == YES) NSLog(@"[iCloud] Document saving and closing");
	// Save and create the new document, then close it
	[document saveToURL:fileURL ofType:iCloudFileType forSaveOperation:NSSaveOperation completionHandler:^(NSError *errorOrNil) {
		if (errorOrNil == nil) {
					// Log
					if (self.verboseLogging == YES) NSLog(@"[iCloud] Written, saved and closed document");
					
					handler(document, document.contents, nil);
		} else {
					NSLog(@"[iCloud] Error while saving document: %s", __PRETTY_FUNCTION__);
					NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"%s error while saving the document, %@, to iCloud", __PRETTY_FUNCTION__, document.fileURL] code:110 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
					
					handler(document, document.contents, error);
				}
		}];
				
			

}
//---------------------------------------------------------------------------------------------------------------------------------------------//
//------------ Delete -------------------------------------------------------------------------------------------------------------------------//
//---------------------------------------------------------------------------------------------------------------------------------------------//
#pragma mark - Delete

- (void)deleteDocumentWithName:(NSString *)documentName completion:(void (^)(NSError *error))handler {
    // Log delete
    if (self.verboseLogging == YES) NSLog(@"[iCloud] Attempting to delete document");
    
    // Check for iCloud
    if ([self quickCloudCheck] == NO) return;
    
    // Check for nil / null document name
    if (documentName == nil || [documentName isEqualToString:@""]) {
        // Log error
        if (self.verboseLogging == YES) NSLog(@"[iCloud] Specified document name must not be empty");
        return;
    }
    
    @try {
        // Create the URL for the file that is being removed
        NSURL *fileURL = [[self ubiquitousDocumentsDirectoryURL] URLByAppendingPathComponent:documentName];
        
        // Check that the file exists
        if ([fileManager fileExistsAtPath:[fileURL path]]) {
            // Log share
            if (self.verboseLogging == YES) NSLog(@"[iCloud] File exists, attempting to delete it");
            
            // Move to the background thread for safety
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
                
                // Use a file coordinator to safely delete the file
                NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
                [fileCoordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForDeleting error:nil byAccessor:^(NSURL *writingURL) {
                    // Create the error handler
                    NSError *error;
                    
                    [fileManager removeItemAtURL:writingURL error:&error];
                    if (error) {
                        // Log failure
                        NSLog(@"[iCloud] An error occurred while deleting the document: %@", error);
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (handler)
                                handler(error);
                        });
                        
                        return;
                    } else {
                        // Log success
                        if (self.verboseLogging == YES) NSLog(@"[iCloud] The document has been deleted");
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updateFiles];
                            if (handler)
                                handler(nil);
                        });
                        
                        return;
                    }
                    
                }];
            });
        } else {
            // The document could not be found
            NSLog(@"[iCloud] File not found: %@", documentName);
            NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"The document, %@, does not exist at path: %@", documentName, fileURL] code:404 userInfo:[NSDictionary dictionaryWithObject:fileURL forKey:@"FileURL"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (handler)
                    handler(error);
                return;
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"[iCloud] Caught exception while deleting file: %@\n\n%s", exception, __PRETTY_FUNCTION__);
    }
}

@end

