//
//  RawRESTOAuthAppDelegate.m
//  RawRESTOAuth
//
//  Created by Jon Mountjoy on 31/05/2011.
//

#import "RawRESTOAuthAppDelegate.h"

// Jon Added
#import "GTMOAuth2ViewControllerTouch.h"

// Fill these in when creating a new Remote Access client on Force.com 
static NSString *const REST_client_ID = @"13MVG9CVKiXR7Ri5ozJEXFpZnyksbtiNibbLSa0y31DvYGHTUH5mkx4eze04.9L8uLdHDYpPDgWBiEShGIX6gK";
static NSString *const REST_client_secret = @"18903849761750162662";
static NSString *const REST_client_redirect_URI = @"https://developer.force.com/callback/";

// These details work for a standard Force.com login end point
static NSString *const REST_authorization_url = @"https://login.salesforce.com/services/oauth2/authorize?response_type=token&display=touch";
static NSString *const REST_token_URL = @"https://login.salesforce.com/services/oauth2/token";
static NSString *const CLIENT_service_name = @"Force.com REST API Demo Client";

@implementation RawRESTOAuthAppDelegate



@synthesize window=_window;

@synthesize navigationController=_navigationController;


/*
 This is the meat of the integration with the OAuth library.  It creates and configures 
 an OAuth authentication controller.
 */

- (UIViewController *) createAuthorizingViewControllerWithDelegate: (id)finishedDelegate
                                                finishedSelector:(SEL)finishedSelector
{
    
    NSURL *tokenURL = [NSURL URLWithString:REST_token_URL];  // Unsure what this is - Jon
    
    GTMOAuth2Authentication *auth;
    auth = [GTMOAuth2Authentication authenticationWithServiceProvider:CLIENT_service_name
                                                             tokenURL:tokenURL
                                                          redirectURI:REST_client_redirect_URI
                                                             clientID:REST_client_ID
                                                         clientSecret:REST_client_secret];
    auth.scope = @"read";
    NSURL *authURL = [NSURL URLWithString:REST_authorization_url];
    GTMOAuth2ViewControllerTouch *viewController;
    
    //should save in keychain. We don't.
    NSString *keychainItemName = nil;
    
    viewController = [[[GTMOAuth2ViewControllerTouch alloc] initWithAuthentication:auth
                                                                  authorizationURL:authURL
                                                                  keychainItemName:keychainItemName
                                                                          delegate:finishedDelegate
                                                                  finishedSelector:finishedSelector] autorelease];
    
    // viewController.browserCookiesURL = [NSURL URLWithString:@"https://login.salesforce.com/"];
    
    viewController.modalPresentationStyle = UIModalPresentationFormSheet;
     
    return viewController; 
}


- (void)hideLogin 
{
    
	[self.navigationController dismissModalViewControllerAnimated:YES];
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
   
    SEL finishedSel = @selector(viewController:finishedWithAuth:error:);
    UIViewController * authController = [self createAuthorizingViewControllerWithDelegate:self.navigationController.visibleViewController
                                                            finishedSelector:finishedSel];
    

    // Override point for customization after application launch.
    // Add the navigation controller's view to the window and display.
    self.window.rootViewController = self.navigationController;
    
        
    [self.window makeKeyAndVisible];

    [self.navigationController presentModalViewController:authController animated:YES];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

- (void)dealloc
{
    [_window release];
    [_navigationController release];
    [super dealloc];
}

@end
