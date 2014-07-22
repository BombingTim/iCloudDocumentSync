//
//  FileListView.m
//  iCloud For Mac
//
//  Created by Tim on 7/19/14.
//  Copyright (c) 2014 Bombing Brain Interactive. All rights reserved.
//

#import "FileListView.h"

@implementation FileListView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}
- (IBAction)deleteButtonClicked:(id)sender {
	if([self.delegate respondsToSelector:@selector(deleteFileForView:)]) {
		[self.delegate deleteFileForView:self];
	}
}

@end
