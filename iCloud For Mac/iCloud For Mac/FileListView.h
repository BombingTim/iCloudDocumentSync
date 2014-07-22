//
//  FileListView.h
//  iCloud For Mac
//
//  Created by Tim on 7/19/14.
//  Copyright (c) 2014 Bombing Brain Interactive. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@protocol FileListViewDelegate <NSObject>
-(void)deleteFileForView:(id)sender;
@end

@interface FileListView : NSView
@property (weak) IBOutlet NSTextField *mainLabel;
@property (weak) IBOutlet NSTextField *detailLabel;
@property (weak) IBOutlet NSButton *deleteButton;
@property (nonatomic,assign) id<FileListViewDelegate> delegate;
@end
