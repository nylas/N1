path = require 'path'

_ = require 'underscore'
async = require 'async'
CSON = require 'season'
fs = require 'fs-plus'
EmitterMixin = require('emissary').Emitter
{Emitter, CompositeDisposable} = require 'event-kit'
Q = require 'q'
{deprecate} = require 'grim'

ModuleCache = require './module-cache'
ScopedProperties = require './scoped-properties'

TaskRegistry = require './task-registry'
DatabaseObjectRegistry = require './database-object-registry'

try
  packagesCache = require('../package.json')?._N1Packages ? {}
catch error
  packagesCache = {}

# Loads and activates a package's main module and resources such as
# stylesheets, keymaps, grammar, editor properties, and menus.
module.exports =
class Package
  EmitterMixin.includeInto(this)

  @isBundledPackagePath: (packagePath) ->
    if NylasEnv.packages.devMode
      return false unless NylasEnv.packages.resourcePath.startsWith("#{process.resourcesPath}#{path.sep}")

    @resourcePathWithTrailingSlash ?= "#{NylasEnv.packages.resourcePath}#{path.sep}"
    packagePath?.startsWith(@resourcePathWithTrailingSlash)

  @loadMetadata: (packagePath, ignoreErrors=false) ->
    packageName = path.basename(packagePath)
    if @isBundledPackagePath(packagePath)
      metadata = packagesCache[packageName]?.metadata
    unless metadata?
      if metadataPath = CSON.resolve(path.join(packagePath, 'package'))
        try
          metadata = CSON.readFileSync(metadataPath)
        catch error
          throw error unless ignoreErrors
    metadata ?= {}
    metadata.name = packageName

    if metadata.stylesheetMain?
      deprecate("Use the `mainStyleSheet` key instead of `stylesheetMain` in the `package.json` of `#{packageName}`", {packageName})
      metadata.mainStyleSheet = metadata.stylesheetMain

    if metadata.stylesheets?
      deprecate("Use the `styleSheets` key instead of `stylesheets` in the `package.json` of `#{packageName}`", {packageName})
      metadata.styleSheets = metadata.stylesheets

    metadata

  keymaps: null
  menus: null
  stylesheets: null
  stylesheetDisposables: null
  grammars: null
  settings: null
  mainModulePath: null
  resolvedMainModulePath: false
  mainModule: null

  ###
  Section: Construction
  ###

  constructor: (@path, @metadata) ->
    @emitter = new Emitter
    @metadata ?= Package.loadMetadata(@path)
    @bundledPackage = Package.isBundledPackagePath(@path)
    @name = @metadata?.name ? path.basename(@path)
    @displayName = @metadata?.displayName || @name
    ModuleCache.add(@path, @metadata)
    @reset()
    @declaresNewDatabaseObjects = false

  # TODO FIXME: Use a unique pluginID instead of just the "name"
  # This needs to be included here to prevent a circular dependency error
  pluginId: -> return @name

  ###
  Section: Event Subscription
  ###

  # Essential: Invoke the given callback when all packages have been activated.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDeactivate: (callback) ->
    @emitter.on 'did-deactivate', callback

  on: (eventName) ->
    switch eventName
      when 'deactivated'
        deprecate 'Use Package::onDidDeactivate instead'
      else
        deprecate 'Package::on is deprecated. Use event subscription methods instead.'
    EmitterMixin::on.apply(this, arguments)

  ###
  Section: Instance Methods
  ###

  enable: ->
    NylasEnv.config.removeAtKeyPath('core.disabledPackages', @name)

  disable: ->
    NylasEnv.config.pushAtKeyPath('core.disabledPackages', @name)

  isTheme: ->
    @metadata?.theme?

  measure: (key, fn) ->
    startTime = Date.now()
    value = fn()
    @[key] = Date.now() - startTime
    value

  getType: -> 'nylas'

  getStyleSheetPriority: -> 0

  load: ->
    @measure 'loadTime', =>
      try
        @declaresNewDatabaseObjects = false
        @loadKeymaps()
        @loadMenus()
        @loadStylesheets()
        @settingsPromise = @loadSettings()
        if not @hasActivationCommands()
          mainModule = @requireMainModule()
          return unless mainModule
          @registerModelConstructors(mainModule.modelConstructors)
          @registerTaskConstructors(mainModule.taskConstructors)

      catch error
        console.warn "Failed to load package named '#{@name}'"
        console.warn error.stack ? error
        console.error(error.message, error)
    this

  registerModelConstructors: (constructors=[]) ->
    if constructors.length > 0
      @declaresNewDatabaseObjects = true
      for constructor in constructors
        DatabaseObjectRegistry.register(constructor)

  registerTaskConstructors: (constructors=[]) ->
    for constructor in constructors
      TaskRegistry.register(constructor)

  reset: ->
    @stylesheets = []
    @keymaps = []
    @menus = []
    @grammars = []
    @settings = []

  activate: ->
    @grammarsPromise ?= @loadGrammars()

    unless @activationDeferred?
      @activationDeferred = Q.defer()
      @measure 'activateTime', =>
        @activateResources()
        if @hasActivationCommands()
          @subscribeToActivationCommands()
        else
          @activateNow()

    Q.all([@grammarsPromise, @settingsPromise, @activationDeferred.promise])

  activateNow: ->
    try
      @activateConfig()
      @activateStylesheets()
      if @requireMainModule()
        localState = NylasEnv.packages.getPackageState(@name) ? {}
        @mainModule.activate(localState)
        @mainActivated = true
        @activateServices()
    catch e
      console.log e.message
      console.log e.stack
      console.warn "Failed to activate package named '#{@name}'", e.stack

    @activationDeferred?.resolve()

  activateConfig: ->
    return if @configActivated

    @requireMainModule()
    if @mainModule?
      if @mainModule.config? and typeof @mainModule.config is 'object'
        NylasEnv.config.setSchema @name, {type: 'object', properties: @mainModule.config}
      else if @mainModule.configDefaults? and typeof @mainModule.configDefaults is 'object'
        NylasEnv.config.setDefaults(@name, @mainModule.configDefaults)
      @mainModule.activateConfig?()
    @configActivated = true

  activateStylesheets: ->
    return if @stylesheetsActivated

    @stylesheetDisposables = new CompositeDisposable

    priority = @getStyleSheetPriority()
    for [sourcePath, source] in @stylesheets
      if match = path.basename(sourcePath).match(/[^.]*\.([^.]*)\./)
        context = match[1]
      else if @metadata.theme is 'syntax'
        context = 'nylas-theme-wrap'
      else
        context = undefined

      @stylesheetDisposables.add(NylasEnv.styles.addStyleSheet(source, {sourcePath, priority, context}))
    @stylesheetsActivated = true

  activateResources: ->
    @activationDisposables = new CompositeDisposable
    @activationDisposables.add(NylasEnv.keymaps.add(keymapPath, map)) for [keymapPath, map] in @keymaps
    @activationDisposables.add(NylasEnv.menu.add(map['menu'])) for [menuPath, map] in @menus when map['menu']?

    unless @grammarsActivated
      grammar.activate() for grammar in @grammars
      @grammarsActivated = true

    settings.activate() for settings in @settings
    @settingsActivated = true

  activateServices: ->
    for name, {versions} of @metadata.providedServices
      for version, methodName of versions
        @activationDisposables.add NylasEnv.packages.serviceHub.provide(name, version, @mainModule[methodName]())

    for name, {versions} of @metadata.consumedServices
      for version, methodName of versions
        @activationDisposables.add NylasEnv.packages.serviceHub.consume(name, version, @mainModule[methodName].bind(@mainModule))

  loadKeymaps: ->
    if @bundledPackage and packagesCache[@name]?
      @keymaps = (["#{NylasEnv.packages.resourcePath}#{path.sep}#{keymapPath}", keymapObject] for keymapPath, keymapObject of packagesCache[@name].keymaps)
    else
      @keymaps = @getKeymapPaths().map (keymapPath) -> [keymapPath, NylasEnv.keymaps.readKeymap(keymapPath) ? {}]

  loadMenus: ->
    if @bundledPackage and packagesCache[@name]?
      @menus = (["#{NylasEnv.packages.resourcePath}#{path.sep}#{menuPath}", menuObject] for menuPath, menuObject of packagesCache[@name].menus)
    else
      @menus = @getMenuPaths().map (menuPath) -> [menuPath, CSON.readFileSync(menuPath) ? {}]

  getKeymapPaths: ->
    keymapsDirPath = path.join(@path, 'keymaps')
    if @metadata.keymaps
      @metadata.keymaps.map (name) -> fs.resolve(keymapsDirPath, name, ['json', 'cson', ''])
    else
      fs.listSync(keymapsDirPath, ['cson', 'json'])

  getMenuPaths: ->
    menusDirPath = path.join(@path, 'menus')
    if @metadata.menus
      @metadata.menus.map (name) -> fs.resolve(menusDirPath, name, ['json', 'cson', ''])
    else
      fs.listSync(menusDirPath, ['cson', 'json'])

  loadStylesheets: ->
    @stylesheets = @getStylesheetPaths().map (stylesheetPath) ->
      [stylesheetPath, NylasEnv.themes.loadStylesheet(stylesheetPath, true)]

  getStylesheetsPath: ->
    if fs.isDirectorySync(path.join(@path, 'stylesheets'))
      deprecate("Store package style sheets in the `styles/` directory instead of `stylesheets/` in the `#{@name}` package", packageName: @name)
      path.join(@path, 'stylesheets')
    else
      path.join(@path, 'styles')

  getStylesheetPaths: ->
    stylesheetDirPath = @getStylesheetsPath()
    if @metadata.mainStyleSheet
      [fs.resolve(@path, @metadata.mainStyleSheet)]
    else if @metadata.styleSheets
      @metadata.styleSheets.map (name) -> fs.resolve(stylesheetDirPath, name, ['css', 'less', ''])
    else if indexStylesheet = fs.resolve(@path, 'index', ['css', 'less'])
      [indexStylesheet]
    else
      _.filter fs.listSync(stylesheetDirPath, ['css', 'less']), (file) ->
        path.basename(file)[0] isnt '.'

  loadGrammarsSync: ->
    return if @grammarsLoaded

    grammarsDirPath = path.join(@path, 'grammars')
    grammarPaths = fs.listSync(grammarsDirPath, ['json', 'cson'])
    for grammarPath in grammarPaths
      try
        grammar = NylasEnv.grammars.readGrammarSync(grammarPath)
        grammar.packageName = @name
        @grammars.push(grammar)
        grammar.activate()
      catch error
        console.warn("Failed to load grammar: #{grammarPath}", error.stack ? error)

    @grammarsLoaded = true
    @grammarsActivated = true

  loadGrammars: ->
    return Q() if @grammarsLoaded

    loadGrammar = (grammarPath, callback) =>
      NylasEnv.grammars.readGrammar grammarPath, (error, grammar) =>
        if error?
          console.warn("Failed to load grammar: #{grammarPath}", error.stack ? error)
        else
          grammar.packageName = @name
          @grammars.push(grammar)
          grammar.activate() if @grammarsActivated
        callback()

    deferred = Q.defer()
    grammarsDirPath = path.join(@path, 'grammars')
    fs.list grammarsDirPath, ['json', 'cson'], (error, grammarPaths=[]) ->
      async.each grammarPaths, loadGrammar, -> deferred.resolve()
    deferred.promise

  loadSettings: ->
    @settings = []

    loadSettingsFile = (settingsPath, callback) =>
      ScopedProperties.load settingsPath, (error, settings) =>
        if error?
          console.warn("Failed to load package settings: #{settingsPath}", error.stack ? error)
        else
          @settings.push(settings)
          settings.activate() if @settingsActivated
        callback()

    deferred = Q.defer()

    if fs.isDirectorySync(path.join(@path, 'scoped-properties'))
      settingsDirPath = path.join(@path, 'scoped-properties')
      deprecate("Store package settings files in the `settings/` directory instead of `scoped-properties/`", packageName: @name)
    else
      settingsDirPath = path.join(@path, 'settings')

    fs.list settingsDirPath, ['json', 'cson'], (error, settingsPaths=[]) ->
      async.each settingsPaths, loadSettingsFile, -> deferred.resolve()
    deferred.promise

  serialize: ->
    if @mainActivated
      try
        @mainModule?.serialize?()
      catch e
        console.error "Error serializing package '#{@name}'", e.stack

  deactivate: ->
    @activationDeferred?.reject()
    @activationDeferred = null
    @activationCommandSubscriptions?.dispose()
    @deactivateResources()
    @deactivateConfig()
    if @mainActivated
      try
        @mainModule?.deactivate?()
      catch e
        console.error "Error deactivating package '#{@name}'", e.stack
    @emit 'deactivated'
    @emitter.emit 'did-deactivate'

  deactivateConfig: ->
    @mainModule?.deactivateConfig?()
    @configActivated = false

  deactivateResources: ->
    grammar.deactivate() for grammar in @grammars
    settings.deactivate() for settings in @settings
    @stylesheetDisposables?.dispose()
    @activationDisposables?.dispose()
    @stylesheetsActivated = false
    @grammarsActivated = false
    @settingsActivated = false

  reloadStylesheets: ->
    oldSheets = _.clone(@stylesheets)
    @loadStylesheets()
    @stylesheetDisposables?.dispose()
    @stylesheetDisposables = new CompositeDisposable
    @stylesheetsActivated = false
    @activateStylesheets()

  requireMainModule: ->
    return @mainModule if @mainModule?
    unless @isCompatible()
      console.warn """
        Failed to require the main module of '#{@name}' because it requires an incompatible native module.
        Run `apm rebuild` in the package directory to resolve.
      """
      return
    mainModulePath = @getMainModulePath()
    @mainModule = require(mainModulePath) if fs.isFileSync(mainModulePath)
    return @mainModule

  getMainModulePath: ->
    return @mainModulePath if @resolvedMainModulePath
    @resolvedMainModulePath = true

    if @bundledPackage and packagesCache[@name]?
      if packagesCache[@name].main
        @mainModulePath = "#{NylasEnv.packages.resourcePath}#{path.sep}#{packagesCache[@name].main}"
        @mainModulePath = fs.resolveExtension(@mainModulePath, ["", _.keys(require.extensions)...])
      else
        @mainModulePath = null
    else
      mainModulePath =
        if @metadata.main
          path.join(@path, @metadata.main)
        else
          path.join(@path, 'index')
      @mainModulePath = fs.resolveExtension(mainModulePath, ["", _.keys(require.extensions)...])

  hasActivationCommands: ->
    for selector, commands of @getActivationCommands()
      return true if commands.length > 0
    false

  subscribeToActivationCommands: ->
    @activationCommandSubscriptions = new CompositeDisposable
    for selector, commands of @getActivationCommands()
      for command in commands
        do (selector, command) =>
          # Add dummy command so it appears in menu.
          # The real command will be registered on package activation
          @activationCommandSubscriptions.add NylasEnv.commands.add selector, command, ->
          @activationCommandSubscriptions.add NylasEnv.commands.onWillDispatch (event) =>
            return unless event.type is command
            currentTarget = event.target
            while currentTarget
              if currentTarget.webkitMatchesSelector(selector)
                @activationCommandSubscriptions.dispose()
                @activateNow()
                break
              currentTarget = currentTarget.parentElement

  getActivationCommands: ->
    return @activationCommands if @activationCommands?

    @activationCommands = {}

    if @metadata.activationCommands?
      for selector, commands of @metadata.activationCommands
        @activationCommands[selector] ?= []
        if _.isString(commands)
          @activationCommands[selector].push(commands)
        else if _.isArray(commands)
          @activationCommands[selector].push(commands...)

    if @metadata.activationEvents?
      deprecate """
        Use `activationCommands` instead of `activationEvents` in your package.json
        Commands should be grouped by selector as follows:
        ```json
          "activationCommands": {
            "nylas-workspace": ["foo:bar", "foo:baz"],
            "nylas-theme-wrap": ["foo:quux"]
          }
        ```
      """
      if _.isArray(@metadata.activationEvents)
        for eventName in @metadata.activationEvents
          @activationCommands['nylas-workspace'] ?= []
          @activationCommands['nylas-workspace'].push(eventName)
      else if _.isString(@metadata.activationEvents)
        eventName = @metadata.activationEvents
        @activationCommands['nylas-workspace'] ?= []
        @activationCommands['nylas-workspace'].push(eventName)
      else
        for eventName, selector of @metadata.activationEvents
          selector ?= 'nylas-workspace'
          @activationCommands[selector] ?= []
          @activationCommands[selector].push(eventName)

    @activationCommands

  # Does the given module path contain native code?
  isNativeModule: (modulePath) ->
    try
      fs.listSync(path.join(modulePath, 'build', 'Release'), ['.node']).length > 0
    catch error
      false

  # Get an array of all the native modules that this package depends on.
  # This will recurse through all dependencies.
  getNativeModuleDependencyPaths: ->
    nativeModulePaths = []

    traversePath = (nodeModulesPath) =>
      try
        for modulePath in fs.listSync(nodeModulesPath)
          nativeModulePaths.push(modulePath) if @isNativeModule(modulePath)
          traversePath(path.join(modulePath, 'node_modules'))

    traversePath(path.join(@path, 'node_modules'))
    nativeModulePaths

  # Get the incompatible native modules that this package depends on.
  # This recurses through all dependencies and requires all modules that
  # contain a `.node` file.
  #
  # This information is cached in local storage on a per package/version basis
  # to minimize the impact on startup time.
  getIncompatibleNativeModules: ->
    localStorageKey = "installed-packages:#{@name}:#{@metadata.version}"
    unless NylasEnv.inDevMode()
      try
        {incompatibleNativeModules} = JSON.parse(global.localStorage.getItem(localStorageKey)) ? {}
      return incompatibleNativeModules if incompatibleNativeModules?

    incompatibleNativeModules = []
    for nativeModulePath in @getNativeModuleDependencyPaths()
      try
        require(nativeModulePath)
      catch error
        try
          version = require("#{nativeModulePath}/package.json").version
        incompatibleNativeModules.push
          path: nativeModulePath
          name: path.basename(nativeModulePath)
          version: version
          error: error.message

    global.localStorage.setItem(localStorageKey, JSON.stringify({incompatibleNativeModules}))
    incompatibleNativeModules

  # Public: Is this package compatible with this version of N1?
  #
  # Incompatible packages cannot be activated. This will include packages
  # installed to ~/.nylas/packages that were built against node 0.11.10 but
  # now need to be upgrade to node 0.11.13.
  #
  # Returns a {Boolean}, true if compatible, false if incompatible.
  isCompatible: ->
    return @compatible if @compatible?

    if @path.indexOf(path.join(NylasEnv.packages.resourcePath, 'node_modules') + path.sep) is 0
      # Bundled packages are always considered compatible
      @compatible = true
    else if packageMain = @getMainModulePath()
      @incompatibleModules = @getIncompatibleNativeModules()
      @compatible = @incompatibleModules.length is 0
    else
      @compatible = true
