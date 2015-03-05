_ = require 'lodash'
path = require 'path'
fs = require 'fs'
CSON = require 'cson-parser'
schemas = require './schemas'

module.exports =
  maxRecentBuilds: 50
  port: 80

configFilename = path.join __dirname, '../config.cson'
if fs.existsSync(configFilename)
  config = CSON.parse(fs.readFileSync(configFilename, encoding: 'utf8'))
  schemas.validate config, 'config'
  _.merge module.exports, config