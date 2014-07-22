//
//  WelcomeViewController.m
//  iCloud For Mac
//
//  Created by Tim on 7/18/14.
//  Copyright (c) 2014 Bombing Brain Interactive. All rights reserved.
//

#import "WelcomeViewController.h"
#import <iCloud/iCloud_OSX.h>

@interface WelcomeViewController () <iCloudDelegate>
@property (weak) IBOutlet NSButton *setupButton;

@property (nonatomic) BOOL isiCloudSetup;
@end

@implementation WelcomeViewController

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
		
	self.isiCloudSetup = NO;
	
	self.view.layer.backgroundColor = CGColorCreateGenericRGB(0xFF/255.0, 0xFF/255.0, 0xFF/255.0, 1.0);
	
	BOOL cloudIsAvailable = [[iCloud sharedCloud] checkCloudAvailability];
	
	[self configureButton:cloudIsAvailable];
}

-(NSInteger)showAlert:(NSString *)message buttonTitles:(NSArray *)titles {
	 NSAlert *alert = [[NSAlert alloc] init];
	 for(NSString *title in titles) {
		[alert addButtonWithTitle:title];
	}
	
	[alert setMessageText:message];
	[alert setAlertStyle:NSWarningAlertStyle];
	
	return [alert runModal];
}
- (IBAction)setupButtonClicked:(id)sender {
	if(self.isiCloudSetup == NO) {//not yet setup
		 if ([[NSUserDefaults standardUserDefaults] boolForKey:APP_USER_DEFAULT_KEY_USER_ICLOUD_PREF] == NO) {
			
			NSInteger response = [self showAlert:@"You have disabled iCloud for this app. Would you like to turn it on again?" buttonTitles:@[@"Cancel",@"Turn On iCloud"]];
			if(response == NSAlertSecondButtonReturn) {
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:APP_USER_DEFAULT_KEY_USER_ICLOUD_PREF];
				[[NSUserDefaults standardUserDefaults] synchronize];
        
				BOOL cloudAvailable = [[iCloud sharedCloud] checkCloudAvailability];
				[self configureButton:cloudAvailable];
			}

		} else {
			[self showAlert:@"iCloud is not available. Sign into an iCloud account on this device and check that this app has valid entitlements." buttonTitles:@[@"Okay"]];
		}
	} else {
		//iCloud is setup...let's rock!
		//Dismiss Welcome Screen and show file list
		
		[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_ICLOUD_READY object:self];
		 

	}

}

-(void)setButton:(NSButton *)button textColor:(NSColor *)color withText:(NSString *)text {

	NSMutableAttributedString *colorTitle =
		[[NSMutableAttributedString alloc] initWithString:text];

	NSRange titleRange = NSMakeRange(0, [colorTitle length]);


	NSMutableParagraphStyle *mutParaStyle=[[NSMutableParagraphStyle alloc] init];
	[mutParaStyle setAlignment:NSCenterTextAlignment];
	
	[colorTitle addAttributes:@{NSParagraphStyleAttributeName:mutParaStyle,
								NSForegroundColorAttributeName:color,
								NSFontAttributeName:[NSFont fontWithName:@"HelveticaNeue-Bold" size:13]
	}
	 range:titleRange];
	
	[button setAttributedTitle:colorTitle];
}

-(void)configureButton:(BOOL)isICloudSetup {
	if (isICloudSetup && [[NSUserDefaults standardUserDefaults] boolForKey:APP_USER_DEFAULT_KEY_USER_ICLOUD_PREF] == YES) {
		self.isiCloudSetup = YES;
		//self.setupButton.title = @"Start Using iCloud";
		[self setButton:self.setupButton textColor:[NSColor whiteColor] withText:@"Start Using iCloud"];
		//Helvetica Neue Bold 13
		self.setupButton.layer.backgroundColor = [[NSColor colorWithCalibratedRed:0/255.0 green:164/255.0 blue:255/255.0 alpha:1.0] CGColor];
	} else {
		self.isiCloudSetup = NO;
		self.setupButton.title = @"Setup iCloud Before Continuing";
		self.setupButton.layer.backgroundColor = [[NSColor yellowColor] CGColor];
	}
}

#pragma mark - ICloud Delegates
- (void)iCloudAvailabilityDidChangeToState:(BOOL)cloudIsAvailable withUbiquityToken:(id)ubiquityToken withUbiquityContainer:(NSURL *)ubiquityContainer {
    [self configureButton:cloudIsAvailable];
}
@end
