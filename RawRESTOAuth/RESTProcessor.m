//
//  RESTProcessor.m
//  BeginnerForcedotcom
//
//  Created by Jon Mountjoy on 12/05/2011.

//  This class effectively does two this:
//  - it performs the REST query
//  - it implements the callbacks for the NSURLConnection
//

#import "RESTProcessor.h"
#import "SBJSON.h"

@interface RESTProcessor () 

@property SEL finalSelector;
@property (assign) id  finalTarget;
@property (retain) NSMutableData *receivedData;

@end

@implementation RESTProcessor

@synthesize finalSelector;
@synthesize finalTarget;
@synthesize receivedData;


- (void)getAccountsUsingREST:(NSString *) RESTapiUrl sessionId:(NSString *)sessionId  target:(id)target selector:(SEL)selector
{
    // store the final callback 
    self.finalTarget = target;
    self.finalSelector = selector;
    // here's our query
    NSString *queryString = 
    @"Select Id, Name, BillingState, Phone From Account order by Name limit 100";

    // construct the REST URL
    NSString *query = [NSString stringWithFormat:@"%@%@%@",RESTapiUrl , @"query?q=", [queryString stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
    

    NSLog(@"Query URL is %@", query);
    
    // construct the request, adding the session ID into the HTTP Header
    NSMutableURLRequest *theRequest=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:query]];
    [theRequest setValue:[NSString stringWithFormat:@"OAuth %@", sessionId] forHTTPHeaderField:@"Authorization"];

    // go go go. Notice self is the delegate, so connect:didReceiveData etc. will be called
    NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    
    if (theConnection) {
        // Create the NSMutableData to hold the received data.
        receivedData = [[NSMutableData data] retain];
    } else {
        // Inform the user that the connection failed.
        NSLog(@"Got error ");
    }    
    
}

#pragma mark - NSURLConnection Delegate Methods

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to receivedData.
    [receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    // release the connection, and the data object
    [connection release];
    
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    
    // convert received data to a string //TODO: Is that the right encoding?
    NSString *receivedAsString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    
 
    
    NSError * err = nil;
    SBJSON * jsonvalue = [SBJSON  alloc];
    NSDictionary *baseReceivedObject = [jsonvalue objectWithString:receivedAsString error:&err];

    // The JSON looks a bit like this {"totalSize":100,"done":true,"records":[....]}  
    // So we need to grab the "records" 
    // fetch the records
    NSArray *records = [baseReceivedObject objectForKey:@"records"];
    
    // invoke the selector to give them our result
	[finalTarget performSelector: finalSelector withObject: records ];
    
    // release the connection, and the data object
    [connection release];
}


- (void)dealloc
{
    self.finalTarget = nil;
    [receivedData release];
    [super dealloc];
}


@end
