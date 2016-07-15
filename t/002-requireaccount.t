use Test::Nginx::Socket 'no_plan';
run_tests();

__DATA__

=== TEST 1: stormpath.requireAccount 401s with no auth header
--- main_config
env STORMPATH_CLIENT_APIKEY_ID;
env STORMPATH_CLIENT_APIKEY_SECRET;
--- config
  location = /t {
    access_by_lua_block {
      local stormpath = require('stormpath-nginx')
      stormpath.requireAccount()
    }
    content_by_lua_block {
      ngx.say('Authorization: ' .. (ngx.var.http_authorization or ''))
      ngx.say('X-Stormpath-Application-Href: ' .. (ngx.var.http_x_stormpath_application_href or ''))
      ngx.say('X-Stormpath-Account-Href: ' .. (ngx.var.http_x_stormpath_account_href or ''))
    }
  }
--- request
GET /t
--- error_code: 401

=== TEST 2: stormpath.requireAccount 401s with invalid JWT
--- main_config
env STORMPATH_CLIENT_APIKEY_ID;
env STORMPATH_CLIENT_APIKEY_SECRET;
--- config
  location = /t {
    access_by_lua_block {
      local stormpath = require('stormpath-nginx')
      stormpath.requireAccount()
    }
    content_by_lua_block {
      ngx.say('Authorization: ' .. (ngx.var.http_authorization or ''))
      ngx.say('X-Stormpath-Application-Href: ' .. (ngx.var.http_x_stormpath_application_href or ''))
      ngx.say('X-Stormpath-Account-Href: ' .. (ngx.var.http_x_stormpath_account_href or ''))
    }
  }
--- request
GET /t
--- more_headers
Authorization: Bearer BADTOKEN
--- error_code: 401

=== TEST 3: stormpath.requireAccount 401s with jwt without stt: access
--- main_config
env STORMPATH_CLIENT_APIKEY_ID;
env STORMPATH_CLIENT_APIKEY_SECRET;
--- config
  location = /t {
    access_by_lua_block {
      local jwt = require('resty.jwt')
      
      local testJwtContents = {
        header = {
          alg = 'HS256'
        },
        payload = {
          sub = 'https://api.stormpath.com/v1/accounts/7ZbV2MtrCH9Oh6QKKxoyZq',
          iss = 'https://api.stormpath.com/v1/applications/3fQVJ66Zkfp88Cr9y3J6Ob',
          iat = ngx.time() - 5,
          exp = ngx.time() + 3600
        }
      }

      local accessToken = jwt:sign(os.getenv('STORMPATH_CLIENT_APIKEY_SECRET'), testJwtContents)

      ngx.req.set_header('authorization', 'Bearer ' .. accessToken)

      local stormpath = require('stormpath-nginx')
      stormpath.requireAccount()
    }
    content_by_lua_block {
      ngx.say('Authorization: ' .. (ngx.var.http_authorization or ''))
      ngx.say('X-Stormpath-Application-Href: ' .. (ngx.var.http_x_stormpath_application_href or ''))
      ngx.say('X-Stormpath-Account-Href: ' .. (ngx.var.http_x_stormpath_account_href or ''))
    }
  }

--- request
GET /t
--- error_code: 401

=== TEST 4: stormpath.requireAccount 401s with jwt without exp
--- main_config
env STORMPATH_CLIENT_APIKEY_ID;
env STORMPATH_CLIENT_APIKEY_SECRET;
--- config
  location = /t {
    access_by_lua_block {
      local jwt = require('resty.jwt')
      
      local testJwtContents = {
        header = {
          alg = 'HS256',
          stt = 'access'
        },
        payload = {
          sub = 'https://api.stormpath.com/v1/accounts/7ZbV2MtrCH9Oh6QKKxoyZq',
          iss = 'https://api.stormpath.com/v1/applications/3fQVJ66Zkfp88Cr9y3J6Ob',
          iat = ngx.time() - 5
        }
      }

      local accessToken = jwt:sign(os.getenv('STORMPATH_CLIENT_APIKEY_SECRET'), testJwtContents)

      ngx.req.set_header('authorization', 'Bearer ' .. accessToken)

      local stormpath = require('stormpath-nginx')
      stormpath.requireAccount()
    }
    content_by_lua_block {
      ngx.say('Authorization: ' .. (ngx.var.http_authorization or ''))
      ngx.say('X-Stormpath-Application-Href: ' .. (ngx.var.http_x_stormpath_application_href or ''))
      ngx.say('X-Stormpath-Account-Href: ' .. (ngx.var.http_x_stormpath_account_href or ''))
    }
  }

--- request
GET /t
--- error_code: 401

=== TEST 5: stormpath.requireAccount passes headers on valid JWT
--- main_config
env STORMPATH_CLIENT_APIKEY_ID;
env STORMPATH_CLIENT_APIKEY_SECRET;
--- config
  location = /t {
    access_by_lua_block {
      local jwt = require('resty.jwt')
      
      local testJwtContents = {
        header = {
          alg = 'HS256',
          stt = 'access'
        },
        payload = {
          sub = 'https://api.stormpath.com/v1/accounts/7ZbV2MtrCH9Oh6QKKxoyZq',
          iss = 'https://api.stormpath.com/v1/applications/3fQVJ66Zkfp88Cr9y3J6Ob',
          iat = ngx.time() - 5,
          exp = ngx.time() + 3600
        }
      }

      local accessToken = jwt:sign(os.getenv('STORMPATH_CLIENT_APIKEY_SECRET'), testJwtContents)

      ngx.req.set_header('authorization', 'Bearer ' .. accessToken)

      local stormpath = require('stormpath-nginx')
      stormpath.requireAccount()
    }
    content_by_lua_block {
      ngx.say('Authorization: ' .. (ngx.var.http_authorization or ''))
      ngx.say('X-Stormpath-Application-Href: ' .. (ngx.var.http_x_stormpath_application_href or ''))
      ngx.say('X-Stormpath-Account-Href: ' .. (ngx.var.http_x_stormpath_account_href or ''))
    }
  }

--- request
GET /t
--- error_code: 200
--- response_body_like
Authorization: Bearer (.*)
X-Stormpath-Application-Href: https:\/\/api.stormpath.com\/v1\/applications\/3fQVJ66Zkfp88Cr9y3J6Ob
X-Stormpath-Account-Href: https:\/\/api.stormpath.com\/v1\/accounts\/7ZbV2MtrCH9Oh6QKKxoyZq
