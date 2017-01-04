# Stormpath Nginx Integration

[![Slack Status](https://talkstormpath.shipit.xyz/badge.svg)](https://talkstormpath.shipit.xyz)

This is a Stormpath integration written in Lua for the nginx web server.

This integration allows you to use nginx as an API Gateway for your backend, without integrating Stormpath into every service.

# Why use an nginx plugin?

Instead of installing a Stormpath integration into each one of your microservices' codebases, you can instead have nginx handle your authentication. Integrating Stormpath into your nginx.conf file is as easy as:

```nginx
location /api/ {
    access_by_lua_block {
        local stormpath = require("stormpath-nginx")
        stormpath.requireAccount()
    }
    proxy_pass http://localhost:3000/;
}
```

When a user makes a request to `/api/*`, Stormpath will look for and validate an access token for the request. If no access token is found, Stormpath will ask nginx to render a `401 Unauthorized` page. Otherwise, Stormpath will allow the request through and add the following headers:

* `X-Stormpath-Account-Href` - a link to the authenticated Stormpath account.
* `X-Stormpath-Application-Href` - a link to the Stormpath application that issued the access token.

The Stormpath nginx integration also exposes an OAuth 2.0 endpoint that can issue access and refresh tokens for authenticated users. 

# Installation

Stormpath's nginx integration requires the use of [OpenResty](https://openresty.org/). To use the nginx integration, make sure you have the following installed and configured: 

* [OpenResty](https://openresty.org/) - a distribution of the nginx web server that includes the lua plugin
* [Lua](https://www.lua.org/download.html) - the Lua programming language
* [Luarocks](https://github.com/keplerproject/luarocks/wiki/Download) - a Lua package manager

If you're new to OpenResty, the following tips will help you make sure you configure Lua properly: 

* When installing Lua, don't forget to `sudo make install` after building Lua with `make linux test`
* You should add Luarocks modules to your lua path by running this command and adding it to your `.bash_profile` file: `eval $(luarocks path --bin)`. Otherwise, nginx will not detect your Luarocks modules. 

With Luarocks, you can install the Stormpath nginx plugin with: 

```bash
$ luarocks install stormpath-nginx --local
```

# Usage

If it's your first time using OpenResty, check out the [Getting Started with OpenResty](https://openresty.org/en/getting-started.html) guide on how to configure and run nginx. You should also take a look at the [example.nginx.conf](example.nginx.conf) file to see how an nginx.conf file is structured. 

The Stormpath plugin allows you to perform access control by adding code in the `access_by_lua_block` hooks exposed by OpenResty. Nginx will first run your code in the `access_by_lua_block`, and depending on the result, optionally pass the request onto your content handler. 

## Configuring the Stormpath API Key and Secret

As with any other Stormpath integration, the Stormpath nginx plugin reads environment variables to find the API Key and Secret for Stormpath. Sign into the [Stormpath admin console](https://api.stormpath.com/login) to find your API Key and secret, and by running these and adding to your `.bash_profile`:

```
export STORMPATH_CLIENT_APIKEY_ID=
export STORMPATH_CLIENT_APIKEY_SECRET=
export STORMPATH_APPLICATION_HREF=
```

With nginx, you need to explicitly expose environment variables to modules in the configuration, so you need to add into the top level configuration: 

```
env STORMPATH_CLIENT_APIKEY_ID;
env STORMPATH_CLIENT_APIKEY_SECRET;
env STORMPATH_APPLICATION_HREF;
```

Note: `STORMPATH_APPLICATION_HREF` is optional for the Stormpath nginx plugin. 

## Authentication Scheme

The Stormpath nginx plugin expects API clients to authenticate with Stormpath access tokens presented as a Bearer token. This looks like the following:

```http
GET / HTTP/1.1
Authorization: Bearer eyJra...
```

These tokens are validated locally using the Stormpath API Key and Secret pair. 

## Getting the Authenticated Account

You can use the Stormpath plugin to check for an access token, and forward the account details to the end application. Here's what the configuration would look like. 

```nginx
location /api/ {
    access_by_lua_block {
        local stormpath = require("stormpath-nginx")
        stormpath.getAccount()
    }
    proxy_pass http://localhost:3000/;
}
```

In this example, nginx will proxy all requests to `http://localhost:3000/`, and additionally, for requests with a valid Stormpath access token, the plugin will add the following HTTP headers:

* `X-Stormpath-Account-Href` - a URL referencing the authenticated account
* `X-Stormpath-Application-Href` - a URL referencing the application that the account is bound to

## Requiring Authentication

As a convenience, you can also have the Stormpath plugin only allow requests with a valid access token. In this example, Stormpath will deny requests with the default nginx `401 Unauthorized` handler. 

```nginx
server {
    listen 8080;
    error_page 401 /empty;
    location /api/ {
        access_by_lua_block {
            local stormpath = require("stormpath-nginx")
            stormpath.requireAccount()
        }
        proxy_pass http://localhost:3000/;
    }
    location /empty {
        internal;
        return 200 '';
    }
}
```

Note: Since the default nginx `401 Unauthorized` page is a HTML page, this example shows how to override the default handler and instead return an empty body. 

## OAuth Token Endpoint

Stormpath's nginx plugin can also act as an OAuth 2.0 endpoint and issue Stormpath access and refresh tokens. The OAuth handler supports the `password` and `refresh` grant types. 

Since this endpoint requires connectivity to Stormpath, you need to configure nginx to use a DNS resolver, as well as a pem file with your trusted SSL certificates. Add this into your http configuration block:

```nginx
resolver 4.2.2.4;
lua_ssl_trusted_certificate /path/to/your/root/ca/pem/file;
lua_ssl_verify_depth 2;
```

Note: If you're unsure where your root certificate pem file is, check out Go's [root CA search paths](https://golang.org/src/crypto/x509/root_linux.go). The referenced root CA files should work for your linux distribution. If you're on macOS, you'll need to open up Keychain Access, select all of your System Roots certificates, and then go to File > Export Items to export a .pem file. 

Once you have nginx configured, you can add an OAuth endpoint with the following configuration: 

```nginx
location = /oauth/token {
    content_by_lua_block {
        local stormpath = require('stormpath-nginx')
        stormpath.oauthTokenEndpoint()
    }
}
```

The `oauthTokenEndpoint` method requires the environment variable `STORMPATH_APPLICATION_HREF` to be set and exposed as well. Alternatively, you can call the method and pass in an application href :

```nginx
stormpath.oauthTokenEndpoint('https://api.stormpath.com/v1/applications/APPID')
```

## Using the OAuth token endpoint

The OAuth token endpoint supports the password, refresh, and client credentials grant types. More information can be found in the [OAuth spec](https://tools.ietf.org/html/rfc6749), and the [Stormpath OAuth Guide](https://docs.stormpath.com/rest/product-guide/latest/auth_n.html#generating-an-oauth-2-0-access-token) but here's a general overview:

### Password Grant Type

You can get an access token with the following HTTP request:

```http
POST /oauth/token

grant_type=password
&username=<username>
&password=<password>
```

This will respond with the following:

```http
HTTP/1.1 200 OK

{
  "access_token":"2YotnFZFEjr1zCsicMWpAA",
  "expires_in":3600,
  "refresh_token":"tGzv3JOkF0XG5Qx2TlKWIA",
  "token_type":"Bearer"
}
```

Or, deny the request:

```http
HTTP/1.1 400 Bad Request

{
  "error": "invalid_grant",
  "message": "Invalid username or password."
}
```

### Refresh Grant Type

After the access token expires, you might want to get a new one. If your refresh token is still valid, you can use the refresh grant to get a new access token, and expect the same response as above:

```http
POST /oauth/token

grant_type=refresh_token&
refresh_token=<refresh token>
```

### Client Credentials

The OAuth token endpoint also supports the client credentials grant type, which is used to exchange a set of API Keys for an access token. The following request is made, using Basic Authentication with the API Key ID as the username, and API Key Secret as the password:

```http
POST /oauth/token
Authorization: Basic <Base64UrlEncoded(ApiKeyId:ApiKeySecret)>

grant_type=client_credentials
```

This results in the following access token response (or above error response). Note that unlike the password grant type, no refresh token is issued. This is because the API Key / Secret are used to "refresh" the access token. 

```http
{
  "access_token": "eyJra...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

# Tests

Tests are run using the `Test::Nginx` CPAN module. Install it via:

```bash
$ cpan Test::Nginx
```

Then you can run the tests using:

```bash
$ prove t/*.t
```

Integration tests are run via the OAuth subset of the [Stormpath Framework TCK](https://github.com/stormpath/stormpath-framework-tck). 

# Questions?

We're proud of the support we provide. Feel free to open up a GitHub issue, email us at support@stormpath.com, or [join our slack channel](https://talkstormpath.shipit.xyz) and chat with us! 
