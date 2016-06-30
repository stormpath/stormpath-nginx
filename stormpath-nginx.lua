local jwt = require('resty.jwt')
local stormpathApiKeyId = os.getenv('STORMPATH_CLIENT_APIKEY_ID')
local stormpathApiKeySecret = os.getenv('STORMPATH_CLIENT_APIKEY_SECRET')

local M = {}
local Helpers = {}

function M.requireAccount()
  M.getAccount(true)
end

function M.getAccount(required)
  local jwtString = Helpers.getBearerToken()

  if not jwtString then
    return Helpers.exit(required)
  end

  local jwt = jwt:verify(stormpathApiKeySecret, jwtString)

  if not jwt.verified then
    return Helpers.exit(required)
  end

  ngx.req.set_header('X-Stormpath-Application-Href', jwt.payload.iss)
  ngx.req.set_header('X-Stormpath-Account-Href', jwt.payload.sub)

end

function Helpers.exit(required)
  if required then
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
  else
    return ngx.exit(ngx.OK)
  end
end

function Helpers.getBearerToken()
  local authorizationHeader = ngx.var.http_authorization

  if authorizationHeader == nil or not authorizationHeader:isBearerString() then
    return nil
  else
    return authorizationHeader:sub(8)
  end
end

function string:isBearerString()
  return self:len() >= 7 and self:sub(1, 7) == 'Bearer '
end

-- this is for debugging purposes only
function tprint (tbl, indent)
  local result = ''
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      result = result .. formatting
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      result = result .. formatting .. tostring(v)      
    else
      result = result .. formatting .. v
    end
  end
  return result
end

return M