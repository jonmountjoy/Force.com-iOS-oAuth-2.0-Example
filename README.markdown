Force.com iOS oAuth 2.0 Example

This Xcode 4 project shows how to access the Force.com REST API using bog-standard OAuth 2.0 and HTTP.

RESTProcessor - this class contains the HTTP callout to the REST API
RawRESTOauthAppDelegate - contains the authentication logic - essentially configuring the OAuth library for Force.com
OAuth Classes and Resources - this group of files contains the Google Toolbox for Mac - OAuth 2 Controllers and JSON parser - http://code.google.com/p/gtm-oauth2/  I had to modify 2 or 3 lines of code in requestRedirectedToRequest (in GTMOauth2SignIn.m)



To Use
 - Go to Setup -> App Setup -> Develop -> Remote Access on Force.com, and create a new Remote Access.  Use a HTTPS callback URL such as https://developer.force.com/callback/
 - The callback URL isn't actually used, except as a signal.

Take the Consumer Key, Secret, and Callback URL and add them to the RawRESTOauthAppDelegate.m - the first three constants.

You should be good to go.



