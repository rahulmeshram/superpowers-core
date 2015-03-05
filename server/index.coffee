exports.config = require './config'

# Globals
global.SupAPI = require '../SupAPI'
global.SupCore = require '../SupCore'
# global.SupSystem = require '../SupSystem'

# Projects
fs = require 'fs'
projectsPath = "#{__dirname}/../projects"
try fs.mkdirSync projectsPath

# Server
express = require 'express'
app = express()
app.use '/', express.static "#{__dirname}/../public"

httpServer = require('http').createServer app
io = require('socket.io') httpServer, { transports: ['websocket'] }

httpServer.on 'error', (err) =>
  if err.code == 'EADDRINUSE' then SupCore.log "Could not start the server: another application is already listening on port #{exports.config.port}."
  else throw err

# Load plugins
pluginsFullNames = { all: [], byAssetType: {} }
pluginsList = []
shouldIgnorePlugin = (pluginName) -> pluginName.indexOf('.') != -1 or pluginName == 'node_modules'

pluginsPath = "#{__dirname}/../plugins"
for pluginAuthor in fs.readdirSync pluginsPath
  pluginAuthorPath = "#{pluginsPath}/#{pluginAuthor}"

  for pluginName in fs.readdirSync pluginAuthorPath
    continue if shouldIgnorePlugin pluginName
    pluginPath = "#{pluginAuthorPath}/#{pluginName}"
    pluginsList.push { name: pluginName, path: pluginPath, author: pluginAuthor }

    pluginsFullNames.all.push "#{pluginAuthor}/#{pluginName}"
    if fs.existsSync "#{pluginPath}/editors"
      pluginsFullNames.byAssetType[assetType] = "#{pluginAuthor}/#{pluginName}" for assetType in fs.readdirSync "#{pluginPath}/editors"

# First, load all scripting API modules
for plugin in pluginsList
  apiModulePath = "#{plugin.path}/api"
  require apiModulePath if fs.existsSync apiModulePath

# Then, load data modules and expose public stuff
for plugin in pluginsList
  dataModulePath = "#{plugin.path}/data"
  require dataModulePath if fs.existsSync dataModulePath
  app.use "/plugins/#{plugin.author}/#{plugin.name}", express.static "#{plugin.path}/public"

fs.writeFileSync "#{__dirname}/../public/plugins.json", JSON.stringify(pluginsFullNames)

# Project hub
ProjectHub = require './ProjectHub'
hub = new ProjectHub io, projectsPath, (err) ->
  if err? then SupCore.log "Failed to start server:\n#{err.stack}"; return

  SupCore.log "Loaded #{Object.keys(hub.serversById).length} projects."

  httpServer.listen exports.config.port, -> SupCore.log "Server started."

# Save on exit and handle crashes
isQuitting = false

onExit = ->
  return if isQuitting
  isQuitting = true
  httpServer.close()

  SupCore.log 'Saving all projects...'

  hub.saveAll (err) ->
    if err? then SupCore.log "Error while exiting:\n#{err}"
    else SupCore.log 'Exited cleanly.'
    process.exit()

  return

process.on 'SIGINT', onExit
process.on 'message', (msg) -> if msg == 'stop' then onExit(); return

process.on 'uncaughtException', (err) ->
  SupCore.log "The server crashed.\n#{err.stack}"
  process.exit 1
  return