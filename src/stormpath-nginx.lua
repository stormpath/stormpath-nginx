local jwt = require('resty.jwt')
local validators = require('resty.jwt-validators')
local stormpathApplicationHref = os.getenv('STORMPATH_APPLICATION_HREF')
local stormpathApiKeyId = os.getenv('STORMPATH_CLIENT_APIKEY_ID')
local stormpathApiKeySecret = os.getenv('STORMPATH_CLIENT_APIKEY_SECRET')

local M = {}
local Helpers = {}

function M.getAccount()
  getAccount(false)
end

function M.requireAccount()
  getAccount(true)
end

function getAccount(required)
  local jwtString = Helpers.getBearerToken()

  if not jwtString then
    return Helpers.exit(required)
  end

  local claimSpec = {
    exp = validators.required(validators.opt_is_not_expired()),
  }

  local jwt = jwt:verify(stormpathApiKeySecret, jwtString, claimSpec)

  if not (jwt.verified and jwt.header.stt == 'access' and jwt.header.alg == 'HS256') then
    return Helpers.exit(required)
  end

  ngx.req.set_header('x-stormpath-application-href', jwt.payload.iss)
  ngx.req.set_header('x-stormpath-account-href', jwt.payload.sub)
end


local http = require('resty.http')
local cjson = require('cjson')
local httpc = http.new()

function M.oauthTokenEndpoint(applicationHref)
  applicationHref = applicationHref or stormpathApplicationHref
  oauthTokenEndpoint(applicationHref)
end

function oauthTokenEndpoint(applicationHref)
  ngx.req.read_body()

  local headers = ngx.req.get_headers()

  -- Proxy these certain parameters to the Stormpath API
  
  local request = {
    method = ngx.var.request_method,
    body = ngx.req.get_body_data(),
    headers = {
      authorization = 'Basic ' .. ngx.encode_base64(stormpathApiKeyId .. ':' .. stormpathApiKeySecret),
      ['content-type'] = headers['content-type'],
      accept = 'application/json',
      ['user-agent'] = 'stormpath-nginx/1.0.1 nginx/' .. ngx.var.nginx_version
    }
  }

  -- For client credentials requests, we need to transform basic auth to post body parameters

  local apiKeyId, apiKeySecret = Helpers.getBasicAuthCredentials()

  if apiKeyId and apiKeySecret then
    request.body = (request.body or '') .. '&apiKeyId=' .. ngx.escape_uri(apiKeyId) .. 
    '&apiKeySecret=' .. ngx.escape_uri(apiKeySecret)
  end

  -- We also need to pass the X-Stormpath-Agent if present

  if headers['x-stormpath-agent'] then
    request.headers['user-agent'] = headers['x-stormpath-agent'] .. ' ' .. request.headers['user-agent']
  end

  -- Make the request

  local res, err = httpc:request_uri(applicationHref .. '/oauth/token' , request)

  if not res or res.status >= 500 then
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end

  local json = cjson.decode(res.body)
  local response = {}

  -- Respond with a stripped token response or error

  if res.status == 200 then
    response = {
      access_token = json.access_token,
      refresh_token = json.refresh_token,
      token_type = json.token_type,
      expires_in = json.expires_in
    }
  else
    response = {
      error = json.error,
      message = json.message
    }
  end

  ngx.status = res.status
  ngx.header.content_type = res.headers['Content-Type']
  ngx.header.cache_control = 'no-store'
  ngx.header.pragma = 'no-cache'
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

return M