//
//  FileListViewController.m
//  iCloud For Mac
//
//  Created by Tim on 7/19/14.
//  Copyright (c) 2014 Bombing Brain Interactive. All rights reserved.
//

#import <iCloud/iCloud_OSX.h>
#import "FileListViewController.h"
#import "FileListView.h"
#import "WelcomeViewController.h"
#import "DocumentEditViewController.h"

#define TEAM_ID @"C5F2AFAU9T"

@interface FileListViewController () <NSTableViewDataSource, NSTableViewDelegate,iCloudDelegate,DocumentEditViewControllerDelegate,FileListViewDelegate>
@property (weak) IBOutlet NSButton *editButton;
@property (weak) IBOutlet NSButton *addFileButton;
@property (weak) IBOutlet NSView *titleBar;
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSButton *refreshButton;

@property (nonatomic,strong) NSMutableArray *fileNameList;
@property (nonatomic,strong) NSMutableArray *fileObjectList;
@property (nonatomic, strong) WelcomeViewController *welcomeViewController;
@property (nonatomic,strong) DocumentEditViewController *documentEditViewController;
@property (nonatomic) BOOL isEditing;

@end

@implementation FileListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    return self;
}

-(void)loadView {
	[super loadView];
	
	self.titleBar.layer.backgroundColor = [[NSColor colorWithCalibratedRed:0/255.0 green:164/255.0 blue:255/255.0 alpha:1.0] CGColor];
	
	 // Setup iCloud
	 iCloud *cloud = [iCloud sharedCloudWithAppId:[self getAppId]] ;// This will help to begin the sync process and register for document updates

    [cloud setDelegate:self]; // Set this if you plan to use the delegate
    [cloud setVerboseLogging:YES]; // We want detailed feedback about what's going on with iCloud, this is OFF by default
    
    // Setup File List
    if (self.fileNameList == nil) self.fileNameList = [NSMutableArray array];
    if (self.fileObjectList == nil) self.fileObjectList = [NSMutableArray array];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudReady:) name:NOTIFICATION_ICLOUD_READY object:nil];
	
	 // Present Welcome Screen
    if ([self appIsRunningForFirstTime] == YES || [[iCloud sharedCloud] checkCloudAvailability] == NO || [[NSUserDefaults standardUserDefaults] boolForKey:APP_USER_DEFAULT_KEY_USER_ICLOUD_PREF] == NO) {
        [self performSelector:@selector(presentWelcomeViewController) withObject:nil afterDelay:0.1];
        return;
    }

	 /* --- Force iCloud Update ---
     This is done automatically when changes are made, but we want to make sure the view is always updated when presented */
    [[iCloud sharedCloud] updateFiles];
	
    
}
-(void)presentWelcomeViewController {
	if(self.welcomeViewController == nil) {
		self.welcomeViewController = [[WelcomeViewController alloc] initWithNibName:@"WelcomeViewController" bundle:nil];
	}
	
	self.welcomeViewController.view.frame = self.view.frame;
	
	[self.view addSubview:self.welcomeViewController.view];

}

-(NSString *)getAppId {
	return @"C5F2AFAU9T.com.iRare-Media.iCloud-App";
    NSString *bundleID = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    //Generize bundle id
    NSRange dashRange = [bundleID rangeOfString:@"-"];
    if(dashRange.location != NSNotFound) {
        bundleID = [bundleID substringToIndex:dashRange.location];
    }
    
   return [NSString stringWithFormat:@"%@.%@",TEAM_ID, bundleID];
}

- (BOOL)appIsRunningForFirstTime {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:APP_USER_DEFAULT_KEY_HAS_LAUNCHED_ONCE]) {
        // App already launched
        return NO;
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:APP_USER_DEFAULT_KEY_HAS_LAUNCHED_ONCE];
        [[NSUserDefaults standardUserDefaults] synchronize];
        // This is the first launch ever
        return YES;
    }
}

-(NSView *)getViewFromNib:(NSString *)nibName {
	if(nibName == nil) return nil;
	
	NSArray *nibObjects = nil;
	if([[NSBundle mainBundle] loadNibNamed:nibName owner:self topLevelObjects:&nibObjects]) {
		for(id object in nibObjects) {
			if([object isKindOfClass:[NSView class]])
				return object;
		}
	}
	
	return nil;
}

-(void)editDocument:(iCloudDocument *)document {
	if(self.documentEditViewController == nil) {
		self.documentEditViewController = [[DocumentEditViewController alloc] initWithNibName:@"DocumentEditViewController" bundle:nil document:document];
	}
	
	self.documentEditViewController.delegate = self;
	self.documentEditViewController.view.frame = self.view.frame;
	
	[self.view addSubview:self.documentEditViewController.view];
}
- (IBAction)editButtonClicked:(id)sender {
	self.isEditing = !self.isEditing;
	if(self.isEditing) {
		[self.addFileButton setEnabled:NO];
		[self.editButton setTitle:@"Done"];
	} else {
		[self.addFileButton setEnabled:YES];
		[self.editButton setTitle:@"Edit"];
	}
	
	[self.tableView reloadData];
}

- (IBAction)newButtonClicked:(id)sender {
	[self editDocument:nil];
}
- (IBAction)refreshButtonClicked:(id)sender {
	[[iCloud sharedCloud] updateFiles];
}
#pragma mark - Notification Handlers
-(void)iCloudReady:(NSNotification *)notif {
	[self.welcomeViewController.view removeFromSuperview];
	self.welcomeViewController = nil;
}

#pragma mark - DocumentEditViewControllerDelegate methods
-(void)dismissDocumentEditView:(id)sender {
	if(self.documentEditViewController) {
		[self.documentEditViewController.view removeFromSuperview];
		self.documentEditViewController = nil;
		[[iCloud sharedCloud] performSelector:@selector(updateFiles) withObject:nil afterDelay:0.25]; //Update list so that it reflects the changes
	}
}
#pragma mark Table Cell Delegates
-(void)deleteFileForView:(id)sender {
	if(sender == nil) return;
	
	__block NSInteger row = [self.tableView rowForView:sender];
	
	NSString *fileName = [self.fileNameList objectAtIndex:row];
	if(fileName) {
		[[iCloud sharedCloud] deleteDocumentWithName:fileName completion:^(NSError *error) {
            if (error) {
                NSLog(@"Error deleting document: %@", error);
            } else {
                [[iCloud sharedCloud] updateFiles];
                
                [self.fileObjectList removeObjectAtIndex:row];
                [self.fileNameList removeObjectAtIndex:row];
                
				[self.tableView removeRowsAtIndexes:[[NSIndexSet alloc] initWithIndex:row] withAnimation:NSTableViewAnimationEffectFade];
            }
        }];

	}
}

#pragma mark - iCloudDelegate methods
/** @name Optional Delegate Methods */
//@optional

/** Called when the availability of iCloud changes
 
 @param cloudIsAvailable Boolean value that is YES if iCloud is available and NO if iCloud is not available 
 @param ubiquityToken An iCloud ubiquity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has been changed (ex. if the user logged out and then logged in with a different iCloud account). This object may be nil if iCloud is not available for any reason.
 @param ubiquityContainer The root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container is initialized. */
- (void)iCloudAvailabilityDidChangeToState:(BOOL)cloudIsAvailable withUbiquityToken:(id)ubiquityToken withUbiquityContainer:(NSURL *)ubiquityContainer {

}


/** Called when the iCloud initiaization process is finished and the iCloud is available
 
 @param cloudToken An iCloud ubiquity token that represents the current iCloud identity. Can be used to determine if iCloud is available and if the iCloud account has been changed (ex. if the user logged out and then logged in with a different iCloud account). This object may be nil if iCloud is not available for any reason.
 @param ubiquityContainer The root URL path to the current application's ubiquity container. This URL may be nil until the ubiquity container is initialized. */
- (void)iCloudDidFinishInitializingWitUbiquityToken:(id)cloudToken withUbiquityContainer:(NSURL *)ubiquityContainer{

}

/** Called before creating an iCloud Query filter. Specify the type of file to be queried. 
 
 @discussion If this delegate is not implemented or returns nil, all files stored in the documents directory will be queried.
 
 @return An NSString with one file extension formatted like this: @"txt" */
- (NSString *)iCloudQueryLimitedToFileExtension {
	return @"txt";
}


/** Called before an iCloud Query begins.
 @discussion This may be useful to display interface updates. */
- (void)iCloudFileUpdateDidBegin {
	NSLog(@"iCloud File Update Did Begin");
}


/** Called when an iCloud Query ends.
 @discussion This may be useful to display interface updates. */
- (void)iCloudFileUpdateDidEnd{
	NSLog(@"iCloud File Update Did End");
}


/** Tells the delegate that the files in iCloud have been modified
 
 @param files A list of the files now in the app's iCloud documents directory - each NSMetadataItem in the array contains information such as file version, url, localized name, date, etc.
 @param fileNames A list of the file names (NSString) now in the app's iCloud documents directory */
- (void)iCloudFilesDidChange:(NSMutableArray *)files withNewFileNames:(NSMutableArray *)fileNames {
	 // Get the query results
	 if([iCloud sharedCloud].verboseLogging) {
		NSLog(@"Files: %@", fileNames);
	}
    
    self.fileNameList = fileNames; // A list of the file names
    self.fileObjectList = files; // A list of NSMetadata objects with detailed metadata
    
   
    [self.tableView reloadData];

}


/** Sent to the delegate where there is a conflict between a local file and an iCloud file during an upload or download
 
 @discussion When both files have the same modification date and file content, iCloud Document Sync will not be able to automatically determine how to handle the conflict. As a result, this delegate method is called to pass the file information to the delegate which should be able to appropriately handle and resolve the conflict. The delegate should, if needed, present the user with a conflict resolution interface. iCloud Document Sync does not need to know the result of the attempted resolution, it will continue to upload all files which are not conflicting. 
 
 It is important to note that **this method may be called more than once in a very short period of time** - be prepared to handle the data appropriately.
 
 The delegate is only notified about conflicts during upload and download procedures with iCloud. This method does not monitor for document conflicts between documents which already exist in iCloud. There are other methods provided to you to detect document state and state changes / conflicts.
 
 @param cloudFile An NSDictionary with the cloud file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate.
 @param localFile An NSDictionary with the local file and various other information. This parameter contains the fileContent as NSData, fileURL as NSURL, and modifiedDate as NSDate. */
//- (void)iCloudFileConflictBetweenCloudFile:(NSDictionary *)cloudFile andLocalFile:(NSDictionary *)localFile;


#pragma mark - NSTableViewDataSource
//@optional

#pragma mark -
#pragma mark ***** Required Methods (unless bindings are used) *****

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return self.fileNameList.count;
}

/* This method is required for the "Cell Based" TableView, and is optional for the "View Based" TableView. If implemented in the latter case, the value will be set to the view at a given row/column if the view responds to -setObjectValue: (such as NSControl and NSTableCellView).
 */
//- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;

#pragma mark -
#pragma mark ***** Optional Methods *****

/* NOTE: This method is not called for the View Based TableView.
 */
//- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;

/* Sorting support
   This is the indication that sorting needs to be done.  Typically the data source will sort its data, reload, and adjust selections.
*/
//- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors;

/* Dragging Source Support - Required for multi-image dragging. Implement this method to allow the table to be an NSDraggingSource that supports multiple item dragging. Return a custom object that implements NSPasteboardWriting (or simply use NSPasteboardItem). If this method is implemented, then tableView:writeRowsWithIndexes:toPasteboard: will not be called.
 */
//- (id <NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row NS_AVAILABLE_MAC(10_7);

/* Dragging Source Support - Optional. Implement this method to know when the dragging session is about to begin and to potentially modify the dragging session.'rowIndexes' are the row indexes being dragged, excluding rows that were not dragged due to tableView:pasteboardWriterForRow: returning nil. The order will directly match the pasteboard writer array used to begin the dragging session with [NSView beginDraggingSessionWithItems:event:source]. Hence, the order is deterministic, and can be used in -tableView:acceptDrop:row:dropOperation: when enumerating the NSDraggingInfo's pasteboard classes. 
 */
//- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes NS_AVAILABLE_MAC(10_7);

/* Dragging Source Support - Optional. Implement this method to know when the dragging session has ended. This delegate method can be used to know when the dragging source operation ended at a specific location, such as the trash (by checking for an operation of NSDragOperationDelete).
 */
//- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation NS_AVAILABLE_MAC(10_7);

/* Dragging Destination Support - Required for multi-image dragging. Implement this method to allow the table to update dragging items as they are dragged over the view. Typically this will involve calling [draggingInfo enumerateDraggingItemsWithOptions:forView:classes:searchOptions:usingBlock:] and setting the draggingItem's imageComponentsProvider to a proper image based on the content. For View Based TableViews, one can use NSTableCellView's -draggingImageComponents. For cell based TableViews, use NSCell's draggingImageComponentsWithFrame:inView:.
 */
//- (void)tableView:(NSTableView *)tableView updateDraggingItemsForDrag:(id <NSDraggingInfo>)draggingInfo NS_AVAILABLE_MAC(10_7);

/* Dragging Source Support - Optional for single-image dragging. Implement this method to support single-image dragging. Use the more modern tableView:pasteboardWriterForRow: to support multi-image dragging. This method is called after it has been determined that a drag should begin, but before the drag has been started.  To refuse the drag, return NO.  To start a drag, return YES and place the drag data onto the pasteboard (data, owner, etc...).  The drag image and other drag related information will be set up and provided by the table view once this call returns with YES.  'rowIndexes' contains the row indexes that will be participating in the drag.
 */
//- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;

/* Dragging Destination Support - This method is used by NSTableView to determine a valid drop target. Based on the mouse position, the table view will suggest a proposed drop 'row' and 'dropOperation'. This method must return a value that indicates which NSDragOperation the data source will perform. The data source may "re-target" a drop, if desired, by calling setDropRow:dropOperation: and returning something other than NSDragOperationNone. One may choose to re-target for various reasons (eg. for better visual feedback when inserting into a sorted position).
*/
//- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation;

/* Dragging Destination Support - This method is called when the mouse is released over an NSTableView that previously decided to allow a drop via the validateDrop method. The data source should incorporate the data from the dragging pasteboard at this time. 'row' and 'dropOperation' contain the values previously set in the validateDrop: method.
*/
//- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;

/* Dragging Destination Support - NSTableView data source objects can support file promised drags by adding NSFilesPromisePboardType to the pasteboard in tableView:writeRowsWithIndexes:toPasteboard:.  NSTableView implements -namesOfPromisedFilesDroppedAtDestination: to return the results of this data source method.  This method should returns an array of filenames for the created files (filenames only, not full paths).  The URL represents the drop location.  For more information on file promise dragging, see documentation on the NSDraggingSource protocol and -namesOfPromisedFilesDroppedAtDestination:.
*/
//- (NSArray *)tableView:(NSTableView *)tableView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedRowsWithIndexes:(NSIndexSet *)indexSet;

#pragma mark - NSTableViewDelegate 
//@optional

#pragma mark -
#pragma mark ***** View Based TableView Support *****

/* View Based TableView: 
 Non-bindings: This method is required if you wish to turn on the use of NSViews instead of NSCells. The implementation of this method will usually call -[tableView makeViewWithIdentifier:[tableColumn identifier] owner:self] in order to reuse a previous view, or automatically unarchive an associated prototype view for that identifier. The -frame of the returned view is not important, and it will be automatically set by the table. 'tableColumn' will be nil if the row is a group row. Returning nil is acceptable, and a view will not be shown at that location. The view's properties should be properly set up before returning the result.
 
 Bindings: This method is optional if at least one identifier has been associated with the TableView at design time. If this method is not implemented, the table will automatically call -[self makeViewWithIdentifier:[tableColumn identifier] owner:[tableView delegate]] to attempt to reuse a previous view, or automatically unarchive an associated prototype view. If the method is implemented, the developer can setup properties that aren't using bindings.
 
 The autoresizingMask of the returned view will automatically be set to NSViewHeightSizable to resize properly on row height changes.
 */
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	FileListView *fileListView = (FileListView *)[self getViewFromNib:@"FileListView"];
	
	NSString *fileName = [self.fileNameList objectAtIndex:row];
    
    NSNumber *filesize = [[iCloud sharedCloud] fileSize:fileName];
    NSDate *updated = [[iCloud sharedCloud] fileModifiedDate:fileName];
    
    __block NSString *documentStateString = @"";
    [[iCloud sharedCloud] documentStateForFile:fileName completion:^(iCloudDocumentState *documentState, NSString *userReadableDocumentState, NSError *error) {
        if (!error) {
            documentStateString = userReadableDocumentState;
        }
    }];
    
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

	 
	[formatter setDateStyle:NSDateFormatterFullStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	NSString *dateAsString = [formatter stringFromDate:updated];
	 

    NSString *fileDetail = [NSString stringWithFormat:@"%@ bytes, updated %@.\n%@", filesize, dateAsString, documentStateString];
    
    // Configure the cell...
    fileListView.delegate = self;
	fileListView.mainLabel.stringValue = fileName;
    fileListView.detailLabel.stringValue = fileDetail;
    
    if ([documentStateString isEqualToString:@"Document is in conflict"]) {
        fileListView.detailLabel.textColor = [NSColor redColor];
    }
	
	if(self.isEditing) {
		[fileListView.deleteButton setHidden:NO];
	} else {
		[fileListView.deleteButton setHidden:YES];
	}
	return fileListView;
}

/* View Based TableView: The delegate can optionally implement this method to return a custom NSTableRowView for a particular 'row'. The reuse queue can be used in the same way as documented in tableView:viewForTableColumn:row:. The returned view will have attributes properly set to it before it is added to the tableView. Returning nil is acceptable. If nil is returned, or this method isn't implemented, a regular NSTableRowView will be created and used.
 */
//- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row NS_AVAILABLE_MAC(10_7);

/* View Based TableView: Optional: This delegate method can be used to know when a new 'rowView' has been added to the table. At this point, you can choose to add in extra views, or modify any properties on 'rowView'.
 */
//- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row NS_AVAILABLE_MAC(10_7);

/* View Based TableView: Optional: This delegate method can be used to know when 'rowView' has been removed from the table. The removed 'rowView' may be reused by the table so any additionally inserted views should be removed at this point. A 'row' parameter is included. 'row' will be '-1' for rows that are being deleted from the table and no longer have a valid row, otherwise it will be the valid row that is being removed due to it being moved off screen.
 */
//- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row NS_AVAILABLE_MAC(10_7);

#pragma mark -
#pragma mark ***** Cell Based TableView Support *****

/* Allows the delegate to provide further setup for 'cell' in 'tableColumn'/'row'. It is not safe to do drawing inside this method, and you should only setup state for 'cell'.
 */ 
//- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
//- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;

/* Optional - Tool Tip Support
 When the user pauses over a cell, the value returned from this method will be displayed in a tooltip.  'point' represents the current mouse location in view coordinates.  If you don't want a tooltip at that location, return nil or the empty string.  On entry, 'rect' represents the proposed active area of the tooltip.  By default, rect is computed as [cell drawingRectForBounds:cellFrame].  To control the default active area, you can modify the 'rect' parameter.
 */
//- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation;

/* Optional - Expansion ToolTip support
    View Based TableView: This method is not called or used.
    Cell Based TableView: Implement this method and return NO to prevent an expansion tooltip from appearing for a particular cell in a given row and tableColumn. See NSCell.h for more information on expansion tool tips. 
 */
//- (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row NS_AVAILABLE_MAC(10_5);

/*  Optional - Custom tracking support
 It is possible to control the ability to track a cell or not. Normally, only selectable or selected cells can be tracked. If you implement this method, cells which are not selectable or selected can be tracked, and vice-versa. For instance, this allows you to have an NSButtonCell in a table which does not change the selection, but can still be clicked on and tracked.
 */
//- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row NS_AVAILABLE_MAC(10_5);

/*  Optional - Different cells for each row
 A different data cell can be returned for any particular tableColumn and row, or a cell that will be used for the entire row (a full width cell). The returned cell should properly implement copyWithZone:, since the cell may be copied by NSTableView. If the tableColumn is non-nil, and nil is returned, then the table will use the default cell from [tableColumn dataCellForRow:row].
 
 When each row is being drawn, this method will first be called with a nil tableColumn. At this time, you can return a cell that will be used to draw the entire row, acting like a group. If you do return a cell for the 'nil' tableColumn, be prepared to have the other corresponding datasource and delegate methods to be called with a 'nil' tableColumn value. If don't return a cell, the method will be called once for each tableColumn in the tableView, as usual.
 */
//- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row NS_AVAILABLE_MAC(10_5);

#pragma mark -
#pragma mark ***** Common Delegate Methods *****

/* Optional - called whenever the user is about to change the selection. Return NO to prevent the selection from being changed at that time.
 */
//- (BOOL)selectionShouldChangeInTableView:(NSTableView *)tableView;

/* Optional - Return YES if 'row' should be selected and NO if it should not. For better performance and better control over the selection, you should use tableView:selectionIndexesForProposedSelection:. 
*/
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
	if(!self.isEditing) {
		//NOT EDITING
		[[iCloud sharedCloud] retrieveCloudDocumentWithName:[self.fileNameList objectAtIndex:row] completion:^(iCloudDocument *cloudDocument, NSData *documentData, NSError *error) {
			if (!error) {
				__block NSString *fileTitle = cloudDocument.fileURL.lastPathComponent;

				[[iCloud sharedCloud] documentStateForFile:fileTitle completion:^(iCloudDocumentState *documentState, NSString *userReadableDocumentState, NSError *error) {
					if (!error) {
						if (*documentState == iCloudDocumentStateInConflict) {
							// [self performSegueWithIdentifier:@"showConflict" sender:self];
						} else {
							[self editDocument:cloudDocument];
						}
					} else {
						NSLog(@"Error retrieving document state: %@", error);
					}
				}];
			} else {
				NSLog(@"Error retrieving document: %@", error);
			}
		}];
	}
	return NO;
}

/* Optional - Return a set of new indexes to select when the user changes the selection with the keyboard or mouse. If implemented, this method will be called instead of tableView:shouldSelectRow:. This method may be called multiple times with one new index added to the existing selection to find out if a particular index can be selected when the user is extending the selection with the keyboard or mouse. Note that 'proposedSelectionIndexes' will contain the entire newly suggested selection, and you can return the exsiting selection to avoid changing the selection.
*/
//- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes NS_AVAILABLE_MAC(10_5);

//- (BOOL)tableView:(NSTableView *)tableView shouldSelectTableColumn:(NSTableColumn *)tableColumn;

//- (void)tableView:(NSTableView *)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn;
//- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn;
//- (void)tableView:(NSTableView *)tableView didDragTableColumn:(NSTableColumn *)tableColumn;

/* Optional - Variable Row Heights
    Implement this method to support a table with varying row heights. The height returned by this method should not include intercell spacing and must be greater than zero. Performance Considerations: For large tables in particular, you should make sure that this method is efficient. NSTableView may cache the values this method returns, but this should NOT be depended on, as all values may not be cached. To signal a row height change, call -noteHeightOfRowsWithIndexesChanged:. For a given row, the same row height should always be returned until -noteHeightOfRowsWithIndexesChanged: is called, otherwise unpredicable results will happen. NSTableView automatically invalidates its entire row height cache in -reloadData, and -noteNumberOfRowsChanged.
*/
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
	return 60;
}

/* Optional - Type select support
    Implement this method if you want to control the string that is used for type selection. You may want to change what is searched for based on what is displayed, or simply return nil for that 'tableColumn' or 'row' to not be searched. By default, all cells with text in them are searched. The default value when this delegate method is not implemented is [[tableView preparedCellAtColumn:tableColumn row:row] stringValue], and this value can be returned from the delegate method if desired.
*/
//- (NSString *)tableView:(NSTableView *)tableView typeSelectStringForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row NS_AVAILABLE_MAC(10_5);

/* Optional - Type select support
    Implement this method if you want to control how type selection works. Return the first row that matches searchString from within the range of startRow to endRow. It is possible for endRow to be less than startRow if the search will wrap. Return -1 when there is no match. Include startRow as a possible match, but do not include endRow. It is not necessary to implement this method in order to support type select.
*/
//- (NSInteger)tableView:(NSTableView *)tableView nextTypeSelectMatchFromRow:(NSInteger)startRow toRow:(NSInteger)endRow forString:(NSString *)searchString NS_AVAILABLE_MAC(10_5);

/* Optional - Type select support
    Implement this method if you would like to prevent a type select from happening based on the current event and current search string. Generally, this will be called from keyDown: and the event will be a key event. The search string will be nil if no type select has began. 
*/
//- (BOOL)tableView:(NSTableView *)tableView shouldTypeSelectForEvent:(NSEvent *)event withCurrentSearchString:(NSString *)searchString NS_AVAILABLE_MAC(10_5);

/* Optional - Group rows. 
    Implement this method and return YES to indicate a particular row should have the "group row" style drawn for that row. If the cell in that row is an NSTextFieldCell and contains only a stringValue, the "group row" style attributes will automatically be applied for that cell. Group rows are drawn differently depending on the selectionHighlightStyle. For NSTableViewSelectionHighlightStyleRegular, there is a blue gradient background. For NSTableViewSelectionHighlightStyleSourceList, the text is light blue, and there is no background. Also see the related floatsGroupRows property.
*/
//- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row NS_AVAILABLE_MAC(10_5);

/* Optional - Autosizing table columns
 Implement this method if you want to control how wide a column is made when the user double clicks on the resize divider. By default, NSTableView iterates every row in the table, accesses a cell via preparedCellAtRow:column:, and requests the "cellSize" to find the appropriate largest width to use. For large row counts, a monte carlo simulation is done instead of interating every row. For performance and accurate results, it is recommended that this method is implemented when using large tables.
 */
//- (CGFloat)tableView:(NSTableView *)tableView sizeToFitWidthOfColumn:(NSInteger)column NS_AVAILABLE_MAC(10_6);

/*  Optional - Control of column reordering.
 Specifies if the column can be reordered to a new location, or not. 'columnIndex' is the column that is being dragged. The actual NSTableColumn instance can be retrieved from the [tableView tableColumns] array. 'newColumnIndex' is the new proposed target location for 'columnIndex'. When a column is initially dragged by the user, the delegate is first called with a 'newColumnIndex' of -1. Returning NO will disallow that column from being reordered at all. Returning YES allows it to be reordered, and the delegate will be called again when the column reaches a new location. If this method is not implemented, all columns are considered reorderable. 
 */
//- (BOOL)tableView:(NSTableView *)tableView shouldReorderColumn:(NSInteger)columnIndex toColumn:(NSInteger)newColumnIndex NS_AVAILABLE_MAC(10_6);

@end
