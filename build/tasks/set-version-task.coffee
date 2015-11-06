fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  {spawn} = require('./task-helpers')(grunt)

  getVersion = (callback) ->
    onBuildMachine = process.env.JANKY_SHA1 and process.env.JANKY_BRANCH is 'master'
    onWindows = process.platform is 'win32'
    inRepository = fs.existsSync(path.resolve(__dirname, '..', '..', '.git'))
    {version} = require(path.join(grunt.config.get('nylas.appDir'), 'package.json'))
    if onBuildMachine or onWindows or not inRepository
      callback(null, version)
    else
      cmd = 'git'
      args = ['rev-parse', '--short', 'HEAD']
      spawn {cmd, args}, (error, {stdout}={}, code) ->
        commitHash = stdout?.trim?()
        combinedVersion = "#{version}-#{commitHash}"
        callback(error, combinedVersion)

  grunt.registerTask 'set-version', 'Set the version in the plist and package.json', ->
    done = @async()

    getVersion (error, version) ->
      if error?
        done(error)
        return

      appDir = grunt.config.get('nylas.appDir')

      # Replace version field of package.json.
      packageJsonPath = path.join(appDir, 'package.json')
      packageJson = require(packageJsonPath)
      packageJson.version = version
      packageJsonString = JSON.stringify(packageJson)
      fs.writeFileSync(packageJsonPath, packageJsonString)

      if process.platform is 'darwin'
        cmd = 'script/set-version'
        args = [grunt.config.get('nylas.buildDir'), version]
        spawn {cmd, args}, (error, result, code) -> done(error)

      else if process.platform is 'win32'
        shellAppDir = grunt.config.get('nylas.shellAppDir')
        shellExePath = path.join(shellAppDir, 'nylas.exe')

        strings =
          CompanyName: 'Nylas, Inc.'
          FileDescription: 'Nylas'
          LegalCopyright: 'Copyright (C) 2014-2015 Nylas, Inc. All rights reserved'
          ProductName: 'Nylas'
          ProductVersion: version

        rcedit = require('rcedit')
        rcedit(shellExePath, {'version-string': strings}, done)
      else
        done()
