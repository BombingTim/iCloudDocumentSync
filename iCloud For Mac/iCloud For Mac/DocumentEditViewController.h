//
//  DocumentEditViewController.h
//  iCloud For Mac
//
//  Created by Tim on 7/21/14.
//  Copyright (c) 2014 Bombing Brain Interactive. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class iCloudDocument_OSX;

@protocol DocumentEditViewControllerDelegate <NSObject>

-(void)dismissDocumentEditView:(id)sender;

@end
@interface DocumentEditViewController : NSViewController

@property (nonatomic, strong) iCloudDocument_OSX *document;
@property (nonatomic, assign) id<DocumentEditViewControllerDelegate> delegate;

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil document:(iCloudDocument_OSX *)document;
@end
