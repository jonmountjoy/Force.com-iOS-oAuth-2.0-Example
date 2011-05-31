//
//  RawRESTOAuthAppDelegate.h
//  RawRESTOAuth
//
//  Created by Jon Mountjoy on 31/05/2011.
//

#import <UIKit/UIKit.h>

@interface RawRESTOAuthAppDelegate : NSObject <UIApplicationDelegate> {

    UIViewController *oAuthViewController;
}

- (UIViewController *) createAuthorizingViewControllerWithDelegate: (id)delegate
                                                  finishedSelector:(SEL)finishedSelector;


@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;


//method to hide oauth login
- (void)hideLogin;


@end
