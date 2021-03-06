/* Copyright (c) 2011 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
// GTMOAuth2ViewControllerTouch.m
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

#if GTM_INCLUDE_OAUTH2 || (!GTL_REQUIRE_SERVICE_INCLUDES && !GDATA_REQUIRE_SERVICE_INCLUDES)

#if TARGET_OS_IPHONE

#define GTMOAUTH2VIEWCONTROLLERTOUCH_DEFINE_GLOBALS 1
#import "GTMOAuth2ViewControllerTouch.h"

#import "GTMOAuth2SignIn.h"
#import "GTMOAuth2Authentication.h"

static NSString * const kGTMOAuth2AccountName = @"OAuth";
static GTMOAuth2Keychain* sDefaultKeychain = nil;

@interface GTMOAuth2ViewControllerTouch()

@property (nonatomic, copy) NSURLRequest *request;

- (void)signIn:(GTMOAuth2SignIn *)signIn displayRequest:(NSURLRequest *)request;
- (void)signIn:(GTMOAuth2SignIn *)signIn
finishedWithAuth:(GTMOAuth2Authentication *)auth
         error:(NSError *)error;
- (BOOL)isNavigationBarTranslucent;
- (void)moveWebViewFromUnderNavigationBar;
- (void)popView;
- (void)clearBrowserCookies;
@end

@implementation GTMOAuth2ViewControllerTouch

@synthesize request = request_;
@synthesize backButton = backButton_;
@synthesize forwardButton = forwardButton_;
@synthesize navButtonsView = navButtonsView_;
@synthesize rightBarButtonItem = rightBarButtonItem_;
@synthesize keychainItemName = keychainItemName_;
@synthesize initialHTMLString = initialHTMLString_;
@synthesize browserCookiesURL = browserCookiesURL_;
@synthesize signIn = signIn_;
@synthesize userData = userData_;
@synthesize webView = webView_;

- (id)initWithScope:(NSString *)scope
           clientID:(NSString *)clientID
       clientSecret:(NSString *)clientSecret
   keychainItemName:(NSString *)keychainItemName
           delegate:(id)delegate
   finishedSelector:(SEL)finishedSelector {
  // convenient entry point for Google authentication

  GTMOAuth2Authentication *auth;
  auth = [GTMOAuth2SignIn standardGoogleAuthenticationForScope:scope
                                                      clientID:clientID
                                                  clientSecret:clientSecret];
  NSURL *authorizationURL = [GTMOAuth2SignIn googleAuthorizationURL];
  return [self initWithAuthentication:auth
                     authorizationURL:authorizationURL
                     keychainItemName:keychainItemName
                             delegate:delegate
                     finishedSelector:finishedSelector];
}

#if NS_BLOCKS_AVAILABLE

- (id)initWithScope:(NSString *)scope
           clientID:(NSString *)clientID
       clientSecret:(NSString *)clientSecret
   keychainItemName:(NSString *)keychainItemName
  completionHandler:(void (^)(GTMOAuth2ViewControllerTouch *viewController, GTMOAuth2Authentication *auth, NSError *error))handler {
  // convenient entry point for Google authentication

  GTMOAuth2Authentication *auth;
  auth = [GTMOAuth2SignIn standardGoogleAuthenticationForScope:scope
                                                      clientID:clientID
                                                  clientSecret:clientSecret];
  NSURL *authorizationURL = [GTMOAuth2SignIn googleAuthorizationURL];
  self = [self initWithAuthentication:auth
                     authorizationURL:authorizationURL
                     keychainItemName:keychainItemName
                             delegate:nil
                     finishedSelector:NULL];
  if (self) {
    completionBlock_ = [handler copy];
  }
  return self;
}

#endif

- (id)initWithAuthentication:(GTMOAuth2Authentication *)auth
            authorizationURL:(NSURL *)authorizationURL
            keychainItemName:(NSString *)keychainItemName
                    delegate:(id)delegate
            finishedSelector:(SEL)finishedSelector {

  NSString *nibName = [[self class] authNibName];

  self = [super initWithNibName:nibName bundle:nil];
  if (self != nil) {
    delegate_ = [delegate retain];
    finishedSelector_ = finishedSelector;

    // use the supplied auth and OAuth endpoint URLs
    signIn_ = [[GTMOAuth2SignIn alloc] initWithAuthentication:auth
                                             authorizationURL:authorizationURL
                                                     delegate:self
                                           webRequestSelector:@selector(signIn:displayRequest:)
                                             finishedSelector:@selector(signIn:finishedWithAuth:error:)];

    // if the user is signing in to a Google service, we'll delete the
    // Google authentication browser cookies upon completion
    //
    // for other service domains, or to disable clearing of the cookies,
    // set the browserCookiesURL property explicitly
    NSString *authorizationHost = [signIn_.authorizationURL host];
    if ([authorizationHost isEqual:@"accounts.google.com"]) {
      NSURL *cookiesURL = [NSURL URLWithString:@"https://www.google.com/accounts"];
      [self setBrowserCookiesURL:cookiesURL];
    }

    [self setKeychainItemName:keychainItemName];
  }
  return self;
}

#if NS_BLOCKS_AVAILABLE
- (id)initWithAuthentication:(GTMOAuth2Authentication *)auth
            authorizationURL:(NSURL *)authorizationURL
            keychainItemName:(NSString *)keychainItemName
           completionHandler:(void (^)(GTMOAuth2ViewControllerTouch *viewController, GTMOAuth2Authentication *auth, NSError *error))handler {
  // fall back to the non-blocks init
  self = [self initWithAuthentication:auth
                     authorizationURL:authorizationURL
                     keychainItemName:keychainItemName
                             delegate:nil
                     finishedSelector:NULL];
  if (self) {
    completionBlock_ = [handler copy];
  }
  return self;
}
#endif

- (void)dealloc {
  self.keychainItemName = nil;
  self.initialHTMLString = nil;
  self.backButton = nil;
  self.forwardButton = nil;
  self.navButtonsView = nil;
  self.rightBarButtonItem = nil;
  self.webView = nil;
  self.browserCookiesURL = nil;
  self.userData = nil;

  [signIn_ release];
  [request_ release];
  [delegate_ release];
#if NS_BLOCKS_AVAILABLE
  [completionBlock_ release];
#endif

  [super dealloc];
}

+ (NSString *)authNibName {
  // subclasses may override this to specify a custom nib name
  return @"GTMOAuth2ViewTouch";
}

+ (GTMOAuth2Authentication *)authForGoogleFromKeychainForName:(NSString *)keychainItemName
                                                     clientID:(NSString *)clientID
                                                 clientSecret:(NSString *)clientSecret {
  NSURL *tokenURL = [GTMOAuth2SignIn googleTokenURL];
  NSString *redirectURI = [GTMOAuth2SignIn googleRedirectURI];
  
  GTMOAuth2Authentication *auth;
  auth = [GTMOAuth2Authentication authenticationWithServiceProvider:kGTMOAuth2ServiceProviderGoogle
                                                           tokenURL:tokenURL
                                                        redirectURI:redirectURI
                                                           clientID:clientID
                                                       clientSecret:clientSecret];
  [[self class] authorizeFromKeychainForName:keychainItemName
                              authentication:auth];
  return auth;
}

+ (BOOL)authorizeFromKeychainForName:(NSString *)keychainItemName
                      authentication:(GTMOAuth2Authentication *)newAuth {
  newAuth.accessToken = nil;

  BOOL didGetTokens = NO;
  GTMOAuth2Keychain *keychain = [GTMOAuth2Keychain defaultKeychain];
  NSString *password = [keychain passwordForService:keychainItemName
                                            account:kGTMOAuth2AccountName
                                              error:nil];
  if (password != nil) {
    [newAuth setKeysForResponseString:password];
    didGetTokens = YES;
  }
  return didGetTokens;
}

+ (BOOL)removeAuthFromKeychainForName:(NSString *)keychainItemName {
  GTMOAuth2Keychain *keychain = [GTMOAuth2Keychain defaultKeychain];
  return [keychain removePasswordForService:keychainItemName
                                    account:kGTMOAuth2AccountName
                                      error:nil];
}

+ (BOOL)saveParamsToKeychainForName:(NSString *)keychainItemName
                     authentication:(GTMOAuth2Authentication *)auth {
  [self removeAuthFromKeychainForName:keychainItemName];
  // don't save unless we have a token that can really authorize requests
  if (![auth canAuthorize]) return NO;

  // make a response string containing the values we want to save
  NSString *password = [auth persistenceResponseString];
  GTMOAuth2Keychain *keychain = [GTMOAuth2Keychain defaultKeychain];
  return [keychain setPassword:password
                    forService:keychainItemName
                       account:kGTMOAuth2AccountName
                         error:nil];
}

- (void)loadView {
  NSString *nibPath = nil;
  NSBundle *nibBundle = [self nibBundle];
  if (nibBundle == nil) {
    nibBundle = [NSBundle mainBundle];
  }
  NSString *nibName = self.nibName;
  if (nibName != nil) {
    nibPath = [nibBundle pathForResource:nibName ofType:@"nib"];
  }
  if (nibPath != nil && [[NSFileManager defaultManager] fileExistsAtPath:nibPath]) {
    [super loadView];
  } else {
#if DEBUG
    NSLog(@"missing %@.nib", nibName);
#endif
  }
}


- (void)viewDidLoad {
  // the app may prefer some html other than blank white to be displayed
  // before the sign-in web page loads
  NSString *html = self.initialHTMLString;
  if ([html length] > 0) {
    [[self webView] loadHTMLString:html baseURL:nil];
  }

  rightBarButtonItem_.customView = navButtonsView_;
  self.navigationItem.rightBarButtonItem = rightBarButtonItem_;
}

- (void)popView {
  if (self.navigationController.topViewController == self) {
    if (!self.view.isHidden) {
      // set the flag to our viewWillDisappear method so it knows
      // this is a disappearance initiated by the sign-in object,
      // not the user cancelling via the navigation controller
      isPoppingSelf_ = YES;

      [self.navigationController popViewControllerAnimated:YES];
      self.view.hidden = YES;

      isPoppingSelf_ = NO;
    }
  }
}

- (void)cancelSigningIn {
  // The application has explicitly asked us to cancel signing in
  // (so no further callback is required)
  hasCalledFinished_ = YES;

  [delegate_ autorelease];
  delegate_ = nil;

#if NS_BLOCKS_AVAILABLE
  [completionBlock_ autorelease];
  completionBlock_ = nil;
#endif

  // The sign-in object's cancel method will close the window
  [signIn_ cancelSigningIn];
  hasDoneFinalRedirect_ = YES;
}

#pragma mark Token Revocation

+ (void)revokeTokenForGoogleAuthentication:(GTMOAuth2Authentication *)auth {
  [GTMOAuth2SignIn revokeTokenForGoogleAuthentication:auth];
}

#pragma mark Browser Cookies

- (GTMOAuth2Authentication *)authentication {
  return self.signIn.authentication;
}

- (void)clearBrowserCookies {
  // if browserCookiesURL is non-nil, then get cookies for that URL
  // and delete them from the common application cookie storage
  NSURL *cookiesURL = [self browserCookiesURL];
  if (cookiesURL) {
    NSHTTPCookieStorage *cookieStorage;

    cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies =  [cookieStorage cookiesForURL:cookiesURL];

    for (NSHTTPCookie *cookie in cookies) {
      [cookieStorage deleteCookie:cookie];
    }
  }
}

#pragma mark Accessors

- (void)setNetworkLossTimeoutInterval:(NSTimeInterval)val {
  signIn_.networkLossTimeoutInterval = val;
}

- (NSTimeInterval)networkLossTimeoutInterval {
  return signIn_.networkLossTimeoutInterval;
}

- (BOOL)shouldUseKeychain {
  NSString *name = self.keychainItemName;
  return ([name length] > 0);
}

#pragma mark SignIn callbacks

- (void)signIn:(GTMOAuth2SignIn *)signIn displayRequest:(NSURLRequest *)request {
  // this is the signIn object's webRequest method, telling the controller
  // to either display the request in the webview, or close the window
  //
  // All web requests and all window closing goes through this routine

#if DEBUG
  if (self.navigationController) {
    if (self.navigationController.topViewController != self && request != nil) {
      NSLog(@"Unexpected: Request to show, when already on top. request %@", [request URL]);
    } else if(self.navigationController.topViewController != self && request == nil) {
      NSLog(@"Unexpected: Request to pop, when not on top. request nil");
    }
  }
#endif

  if (request != nil) {
    const NSTimeInterval kJanuary2011 = 1293840000;
    BOOL isDateValid = ([[NSDate date] timeIntervalSince1970] > kJanuary2011);
    if (isDateValid) {
      // Display the request.
      self.request = request;
      [self.webView loadRequest:[self request]];
    } else {
      // clock date is invalid, so signing in would fail with an unhelpful error
      // from the server. Warn the user in an html string showing a watch icon,
      // question mark, and the system date and time. Hopefully this will clue
      // in brighter users, or at least give them a clue when they report the
      // problem to developers.
      //
      // Even better is for apps to check the system clock and show some more
      // helpful, localized instructions for users; this is really a fallback.
      NSString *html = @"<html><body><div align=center><font size='7'>"
        @"&#x231A; ?<br><i>System Clock Incorrect</i><br>%@"
        @"</font></div></body></html>";
      NSString *errHTML = [NSString stringWithFormat:html, [NSDate date]];

      [[self webView] loadHTMLString:errHTML baseURL:nil];
    }
  } else {
    // request was nil.
    [self popView];
  }
}

- (void)signIn:(GTMOAuth2SignIn *)signIn
  finishedWithAuth:(GTMOAuth2Authentication *)auth
             error:(NSError *)error {
  if (!hasCalledFinished_) {
    hasCalledFinished_ = YES;

    if (error == nil) {
      if (self.shouldUseKeychain) {
        NSString *keychainItemName = self.keychainItemName;
        if (auth.canAuthorize) {
          // save the auth params in the keychain
          [[self class] saveParamsToKeychainForName:keychainItemName authentication:auth];
        } else {
          // remove the auth params from the keychain
          [[self class] removeAuthFromKeychainForName:keychainItemName];
        }
      }
    }

    if (delegate_ && finishedSelector_) {
      SEL sel = finishedSelector_;
      NSMethodSignature *sig = [delegate_ methodSignatureForSelector:sel];
      NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
      [invocation setSelector:sel];
      [invocation setTarget:delegate_];
      [invocation setArgument:&self atIndex:2];
      [invocation setArgument:&auth atIndex:3];
      [invocation setArgument:&error atIndex:4];
      [invocation invoke];
    }

    [delegate_ autorelease];
    delegate_ = nil;

#if NS_BLOCKS_AVAILABLE
    if (completionBlock_) {
      completionBlock_(self, auth, error);

      // release the block here to avoid a retain loop on the controller
      [completionBlock_ autorelease];
      completionBlock_ = nil;
    }
#endif
  }
}

- (void)moveWebViewFromUnderNavigationBar {
  CGRect dontCare;
  CGRect webFrame = self.view.bounds;
  UINavigationBar *navigationBar = self.navigationController.navigationBar;
  CGRectDivide(webFrame, &dontCare, &webFrame,
    navigationBar.frame.size.height, CGRectMinYEdge);
  [self.webView setFrame:webFrame];
}

// isTranslucent is defined in iPhoneOS 3.0 on.
- (BOOL)isNavigationBarTranslucent {
  UINavigationBar *navigationBar = [[self navigationController] navigationBar];
  BOOL isTranslucent =
    ([navigationBar respondsToSelector:@selector(isTranslucent)] &&
     [navigationBar isTranslucent]);
  return isTranslucent;
}

#pragma mark -
#pragma mark Protocol implementations

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  if (!isViewShown_) {
    isViewShown_ = YES;
    if ([self isNavigationBarTranslucent]) {
      [self moveWebViewFromUnderNavigationBar];
    }
    if (![signIn_ startSigningIn]) {
      // Can't start signing in. We must pop our view.
      // UIWebview needs time to stabilize. Animations need time to complete.
      // We remove ourself from the view stack after that.
      [self performSelector:@selector(popView)
                 withObject:nil
                 afterDelay:0.5
                    inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
    }
  }
  [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
  if (!isPoppingSelf_) {
    // we are not popping ourselves, so presumably we are being popped by the
    // navigation controller; tell the sign-in object to close up shop
    //
    // this will indirectly call our signIn:finishedWithAuth:error: method
    // for us
    [signIn_ windowWasClosed];
  }

  // prevent the next sign-in from showing in the WebView that the user is
  // already signed in
  [self clearBrowserCookies];

  [super viewWillDisappear:animated];
}

- (BOOL)webView:(UIWebView *)webView
  shouldStartLoadWithRequest:(NSURLRequest *)request
              navigationType:(UIWebViewNavigationType)navigationType {

  if (!hasDoneFinalRedirect_) {
    hasDoneFinalRedirect_ = [signIn_ requestRedirectedToRequest:request];
    if (hasDoneFinalRedirect_) {
      // signIn has told the view to close
      return NO;
    }
  }
  return YES;
}

- (void)updateUI {
  [backButton_ setEnabled:[[self webView] canGoBack]];
  [forwardButton_ setEnabled:[[self webView] canGoForward]];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
  [self updateUI];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
  NSString *title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
  if ([title length] > 0) {
    [signIn_ titleChanged:title];
  }

  [self updateUI];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  BOOL value = YES;
  if (!isInsideShouldAutorotateToInterfaceOrientation_) {
    isInsideShouldAutorotateToInterfaceOrientation_ = YES;
    UIViewController *navigationController = [self navigationController];
    if (navigationController != nil) {
      value = [navigationController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    } else {
      value = [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    }
    isInsideShouldAutorotateToInterfaceOrientation_ = NO;
  }
  return value;
}

@end


#pragma mark Common Code

@implementation GTMOAuth2Keychain

+ (GTMOAuth2Keychain *)defaultKeychain {
  if (sDefaultKeychain == nil) {
    sDefaultKeychain = [[self alloc] init];
  }
  return sDefaultKeychain;
}


// For unit tests: allow setting a mock object
+ (void)setDefaultKeychain:(GTMOAuth2Keychain *)keychain {
  if (sDefaultKeychain != keychain) {
    [sDefaultKeychain release];
    sDefaultKeychain = [keychain retain];
  }
}

- (NSString *)keyForService:(NSString *)service account:(NSString *)account {
  return [NSString stringWithFormat:@"com.google.GTMOAuth.%@%@", service, account];
}

// The Keychain API isn't available on the iPhone simulator in SDKs before 3.0,
// so, on early simulators we use a fake API, that just writes, unencrypted, to
// NSUserDefaults.
#if TARGET_IPHONE_SIMULATOR && __IPHONE_OS_VERSION_MAX_ALLOWED < 30000
#pragma mark Simulator

// Simulator - just simulated, not secure.
- (NSString *)passwordForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
  NSString *result = nil;
  if (0 < [service length] && 0 < [account length]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = [self keyForService:service account:account];
    result = [defaults stringForKey:key];
    if (result == nil && error != NULL) {
      *error = [NSError errorWithDomain:kGTMOAuth2KeychainErrorDomain
                                   code:kGTMOAuth2KeychainErrorNoPassword
                               userInfo:nil];
    }
  } else if (error != NULL) {
    *error = [NSError errorWithDomain:kGTMOAuth2KeychainErrorDomain
                                 code:kGTMOAuth2KeychainErrorBadArguments
                             userInfo:nil];
  }
  return result;

}


// Simulator - just simulated, not secure.
- (BOOL)removePasswordForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
  BOOL didSucceed = NO;
  if (0 < [service length] && 0 < [account length]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = [self keyForService:service account:account];
    [defaults removeObjectForKey:key];
    [defaults synchronize];
  } else if (error != NULL) {
    *error = [NSError errorWithDomain:kGTMOAuth2KeychainErrorDomain
                                 code:kGTMOAuth2KeychainErrorBadArguments
                             userInfo:nil];
  }
  return didSucceed;
}

// Simulator - just simulated, not secure.
- (BOOL)setPassword:(NSString *)password
         forService:(NSString *)service
            account:(NSString *)account
              error:(NSError **)error {
  BOOL didSucceed = NO;
  if (0 < [password length] && 0 < [service length] && 0 < [account length]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = [self keyForService:service account:account];
    [defaults setObject:password forKey:key];
    [defaults synchronize];
    didSucceed = YES;
  } else if (error != NULL) {
    *error = [NSError errorWithDomain:kGTMOAuth2KeychainErrorDomain
                                 code:kGTMOAuth2KeychainErrorBadArguments
                             userInfo:nil];
  }
  return didSucceed;
}

#else // ! TARGET_IPHONE_SIMULATOR
#pragma mark Device

+ (NSMutableDictionary *)keychainQueryForService:(NSString *)service account:(NSString *)account {
  NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                         (id)kSecClassGenericPassword, (id)kSecClass,
                         @"OAuth", (id)kSecAttrGeneric,
                         account, (id)kSecAttrAccount,
                         service, (id)kSecAttrService,
                         nil];
  return query;
}

- (NSMutableDictionary *)keychainQueryForService:(NSString *)service account:(NSString *)account {
  return [[self class] keychainQueryForService:service account:account];
}



// iPhone
- (NSString *)passwordForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
  OSStatus status = kGTMOAuth2KeychainErrorBadArguments;
  NSString *result = nil;
  if (0 < [service length] && 0 < [account length]) {
    CFDataRef passwordData = NULL;
    NSMutableDictionary *keychainQuery = [self keychainQueryForService:service account:account];
    [keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

    status = SecItemCopyMatching((CFDictionaryRef)keychainQuery,
                                       (CFTypeRef *)&passwordData);
    if (status == noErr && 0 < [(NSData *)passwordData length]) {
      result = [[[NSString alloc] initWithData:(NSData *)passwordData
                                      encoding:NSUTF8StringEncoding] autorelease];
    }
    if (passwordData != NULL) {
      CFRelease(passwordData);
    }
  }
  if (status != noErr && error != NULL) {
    *error = [NSError errorWithDomain:kGTMOAuth2KeychainErrorDomain
                                 code:status
                             userInfo:nil];
  }
  return result;
}


// iPhone
- (BOOL)removePasswordForService:(NSString *)service account:(NSString *)account error:(NSError **)error {
  OSStatus status = kGTMOAuth2KeychainErrorBadArguments;
  if (0 < [service length] && 0 < [account length]) {
    NSMutableDictionary *keychainQuery = [self keychainQueryForService:service account:account];
    status = SecItemDelete((CFDictionaryRef)keychainQuery);
  }
  if (status != noErr && error != NULL) {
    *error = [NSError errorWithDomain:kGTMOAuth2KeychainErrorDomain
                                 code:status
                             userInfo:nil];
  }
  return status == noErr;
}

// iPhone
- (BOOL)setPassword:(NSString *)password
         forService:(NSString *)service
            account:(NSString *)account
              error:(NSError **)error {
  OSStatus status = kGTMOAuth2KeychainErrorBadArguments;
  if (0 < [service length] && 0 < [account length]) {
    [self removePasswordForService:service account:account error:nil];
    if (0 < [password length]) {
      NSMutableDictionary *keychainQuery = [self keychainQueryForService:service account:account];
      NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
      [keychainQuery setObject:passwordData forKey:(id)kSecValueData];
      status = SecItemAdd((CFDictionaryRef)keychainQuery, NULL);
    }
  }
  if (status != noErr && error != NULL) {
    *error = [NSError errorWithDomain:kGTMOAuth2KeychainErrorDomain
                                 code:status
                             userInfo:nil];
  }
  return status == noErr;
}

#endif // ! TARGET_IPHONE_SIMULATOR

@end

#endif // TARGET_OS_IPHONE

#endif // #if GTM_INCLUDE_OAUTH2 || (!GTL_REQUIRE_SERVICE_INCLUDES && !GDATA_REQUIRE_SERVICE_INCLUDES)
