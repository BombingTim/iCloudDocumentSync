//
//  AppDelegate.m
//  iCloud For Mac
//
//  Created by Tim on 7/18/14.
//  Copyright (c) 2014 Bombing Brain Interactive. All rights reserved.
//

#import "AppDelegate.h"
#import "FileListViewController.h"

@interface AppDelegate ()
@property(nonatomic, strong) FileListViewController *fileListViewController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{

	//Reset App
	if(1 == 0) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:APP_USER_DEFAULT_KEY_USER_ICLOUD_PREF];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:APP_USER_DEFAULT_KEY_HAS_LAUNCHED_ONCE];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	

	self.mainViewController.view.frame = ((NSView *)self.window.contentView).frame;
	[self.window.contentView addSubview:self.mainViewController.view];
	
}


@end
