//
//  RESTProcessor.h
//
//  Created by Jon Mountjoy on 12/05/2011.
//
//  This class effectively does two this:
//  - it performs the REST query
//  - it implements the callbacks for the NSURLConnection
//

#import <Foundation/Foundation.h>


@interface RESTProcessor : NSObject {

}

// target and selector determine who to call once we've received the results
- (void)getAccountsUsingREST:(NSString *) RESTapiUrl sessionId:(NSString *)sessionId  target:(id)target selector:(SEL)selector;

@end
