package = 'stormpath-nginx'
version = '1.0-1'
source = {
  url = 'git://github.com/stormpath/stormpath-nginx',
  tag = '1.0'
}
description = {
  summary = 'A Stormpath + nginx integration',
  detailed = [[
    Use Nginx as an API Gateway for your Stormpath applications. 
  ]],
  homepage = 'https://stormpath.com/',
  license = 'Apache2'
}
dependencies = {
  'lua >= 5.1',
  'lua-resty-jwt = 0.1.5',
  'lua-resty-http = 0.08'
}
build = {
  type = 'builtin',
  modules = {
    ['stormpath-nginx'] = 'src/stormpath-nginx.lua',
  }
}