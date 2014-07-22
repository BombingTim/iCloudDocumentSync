//
//  DocumentEditViewController.m
//  iCloud For Mac
//
//  Created by Tim on 7/21/14.
//  Copyright (c) 2014 Bombing Brain Interactive. All rights reserved.
//


#import "DocumentEditViewController.h"
#import <iCloud/iCloud_OSX.h>
#import <iCloud/iCloudDocument_OSX.h>

@interface DocumentEditViewController ()
@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSTextField *fileNameLabel;
@property (weak) IBOutlet NSView *titleBar;

@end

@implementation DocumentEditViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil document:(iCloudDocument *)document {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.document = document;
    }
    return self;
}

-(void)loadView {
	[super loadView];
	self.titleBar.layer.backgroundColor = [[NSColor colorWithCalibratedRed:0/255.0 green:164/255.0 blue:255/255.0 alpha:1.0] CGColor];
	if(self.document) {
		self.fileNameLabel.stringValue = self.document.fileURL.lastPathComponent;
		[self.textView setString:[[NSString alloc] initWithData:self.document.contents encoding:NSUTF8StringEncoding]];
	} else {
		self.fileNameLabel.stringValue = @"iCloud Document";
		[self.textView setString:@"Document Text"];
	}
	[self.textView setTextContainerInset:NSMakeSize(5, 5)]; //add margin
	
	
}

- (IBAction)backButtonClicked:(id)sender {
	//Save the data
	NSString *fileName = nil;
	if (([self.fileNameLabel.stringValue isEqualToString:@"iCloud Document"]) || (self.document == nil)) {
		fileName = [self generateFileNameWithExtension:@"txt"];
	} else {
		fileName = self.document.fileURL.lastPathComponent;
	}
		
	 NSData *fileData = [self.textView.string dataUsingEncoding:NSUTF8StringEncoding];
		
	[[iCloud sharedCloud] saveAndCloseDocumentWithName:fileName withContent:fileData completion:^(iCloudDocument *cloudDocument, NSData *documentData, NSError *error) {
		if (!error) {
			NSLog(@"iCloud Document, %@, saved with text: %@", cloudDocument.fileURL.lastPathComponent, [[NSString alloc] initWithData:documentData encoding:NSUTF8StringEncoding]);
		} else {
			NSLog(@"iCloud Document save error: %@", error);
		}
		
		if([self.delegate respondsToSelector:@selector(dismissDocumentEditView:)]) {
			[self.delegate dismissDocumentEditView:self];
		}
		
	}];
	
}

- (NSString *)generateFileNameWithExtension:(NSString *)extensionString {
    NSDate *time = [NSDate date];
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"dd-MM-yyyy-hh-mm-ss"];
    NSString *timeString = [dateFormatter stringFromDate:time];
    
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", timeString, extensionString];
    
    return fileName;
}
@end
