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

  ngx.req.set_header('x-stormpath-application-href', jwt.payload.iss)
  ngx.req.set_header('x-stormpath-account-href', jwt.payload.sub)
end

local http = require('resty.http')
local cjson = require('cjson')
local httpc = http.new()

function M.oauthTokenEndpoint(applicationHref)
  ngx.req.read_body()

  local headers = ngx.req.get_headers()

  local request = {
    method = ngx.var.request_method,
    body = ngx.req.get_body_data(),
    headers = {
      authorization = 'Basic ' .. ngx.encode_base64(stormpathApiKeyId .. ':' .. stormpathApiKeySecret),
      ['content-type'] = headers['content-type']
    }
  }

  local apiKeyId, apiKeySecret = Helpers.getBasicAuthCredentials()

  if apiKeyId and apiKeySecret then
    request.body = (request.body or '') .. '&apiKeyId=' .. apiKeyId .. '&apiKeySecret=' .. apiKeySecret
  end

  local res, err = httpc:request_uri(applicationHref .. '/oauth/token' , request)

  if not res or res.status >= 500 then
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end

  local json = cjson.decode(res.body)
  local response = {}

  if res.status == 200 then
    response = {
      access_token = json.access_token,
      refresh_token = json.refresh_token,
      token_type = json.token_type,
      expires_in = json.expires_in
    }
  else
    response = {
      status = json.status,
      error = json.error,
      message = json.message
    }
  end

  ngx.status = res.status
  ngx.say(cjson.encode(response))
  ngx.exit(ngx.HTTP_OK)
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

  if not authorizationHeader or not authorizationHeader:startsWith('Bearer ') then
    return nil
  else
    return authorizationHeader:sub(8)
  end
end

function Helpers.getBasicAuthCredentials()
  local authorizationHeader = ngx.var.http_authorization

  if not authorizationHeader or not authorizationHeader:startsWith('Basic ') then
    return nil
  else
    local decodedHeader = ngx.decode_base64(authorizationHeader:sub(7))
    local position = decodedHeader:find(':')
    local username = decodedHeader:sub(1,position-1)
    local password = decodedHeader:sub(position+1)

    return username, password
  end
end

function string:startsWith(partialString)
  local partialStringLength = partialString:len()
  return self:len() >= partialStringLength and self:sub(1, partialStringLength) == partialString
end

function Helpers.copy(headers)
  local result = {}
  for k,v in pairs(headers) do
    result[k] = v
  end
  return result
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
  ngx.say(result)
  ngx.exit(ngx.OK)
end

return M