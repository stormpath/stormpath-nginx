use Test::Nginx::Socket 'no_plan';
run_tests();

__DATA__

=== TEST 1: nginx doesn't crash when using the Stormpath module
--- config
  location = /t {
    content_by_lua_block {
      local stormpath = require("stormpath-nginx")
    }
  }
--- request
GET /t
--- error_code: 200

=== TEST 2: Stormpath client environment variables are set
--- main_config
env STORMPATH_CLIENT_APIKEY_ID;
env STORMPATH_CLIENT_APIKEY_SECRET;
--- config
  location = /t {
    content_by_lua_block {
      ngx.print(os.getenv('STORMPATH_CLIENT_APIKEY_ID') == nil or os.getenv('STORMPATH_CLIENT_APIKEY_SECRET') == nil)
    }
  }
--- request
GET /t
--- response_body
false