# AtFindAPI
The at_find_api is a small, read only HTTP server that can be used 
to lookup public information for any @sign using a browser or any 
other HTTP client. To see it work, open a browser window and go to:

https://atsign.directory

In the above case, the server will return the at_find_me web 
application that allows the user to lookup information for any 
@sign that the owner has set to public.

The AtFindAPI serves three purposes:

## 1. Read only web server
Like most web servers, it can serve up any arbitrary content typical of a 
modern web application. For example, the URL above returns content from the 
at_find_me web application that has been copied into the "web" 
directory for this server. 

Interestingly, this server only responds to GET or HEAD requests - the use 
of any other HTTP verbs will generate an error. This is out of an 
abundance of caution and is due to our paranoia about security.

## 2. Read only REST API that returns JSON data for an @protocol request
The following endpoint; <code>/api</code> is used to make data requests
by including an url parameter (<code>?atp=</code>) followed by an @ 
protocol syntax (either an <code>@entity</code> or 
<code>service@entity</code>) request. 

For example, <code>@bob🛠</code> will return all public values for 
@bob🛠 as JSON as shown below:

https://atsign.directory/api?atp=@bob🛠

Whereas <code>phone@bob🛠</code> will return all the value for the 
service "phone" that @bob🛠 has set to public as JSON as shown below: 

https://atsign.directory/api?atp=phone@bob🛠

## 3. Check the status of a @eerver for a particular @sign
You can also check the status of an @server server using this endpoint:

https://atsign.directory/status/<@sign>

This endpoint does not return any content, instead it returns an http response code as follows:
```
static const int notFound = 404
// Not Found(404) @server has no root location, is not running and is not activated

static const int serviceUnavailable = 503
// Service Unavailable(503) @server has root location, is not running and is not activated

int 418
// I'm a teapot(418) @server has root location, is running and but not activated

static const int ok = 200
// OK (200) @server has root location, is running and is activated

static const int internalServerError = 500
// Internal Server Error(500) at_find_api internal error

static const int badGateway = 502
// Bad Gateway(502) @root server is down

static const int methodNotAllowed = 405
// Method Not Allowed(405) only GET and HEAD are allowed
```

# How to deploy and run
You can either use the current executable in the bin directory or compile 
from the source to the output directory you want to use.
```
dart2native bin/main.dart -o ~/test/directory
```
You must copy any web content you want to serve to the <code>/web</code> 
directory. For example, if you build the at_find_me web application and copy 
the build contents to the web directory for this project, the AtFindAPI 
will then serve that content for you.

You must also copy config directory and config.yaml to the directory that
you want to serve up the api.

## Running locally
You can start the service from the command line by running the following 
command from the directory that you deployed to, specifying the port 
you want to use:
```
dart ./bin/main.dart 6464
```
Then, you can access it via the browser or other http client as 
shown above with localhost. For example, 

http://localhost:6464/#/@me
