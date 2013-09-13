crypto = require 'crypto'
fs = require 'fs'
{basename, dirname, extname, join} = require 'path'

_ = require 'underscore'
{Parser} = require 'less'
mkdir = require('mkdirp').sync
rm = require('rimraf').sync
walkdir = require('walkdir').sync

cacheVersion = 1

module.exports =
class LessCache
  constructor: ({@cacheDir, importPaths}={}) ->
    try
      {@importedFiles} = @readJson(join(@cacheDir, 'imports.json'))

    @setImportPaths(importPaths)

  getDirectory: -> @cacheDir

  getImportPaths: -> _.clone(@importPaths)

  setImportPaths: (@importPaths=[]) ->
    importedFiles = []
    for importPath in @importPaths
      walkdir importPath, (filePath, stat) ->
        importedFiles.push(filePath) if stat.isFile()

    unless _.isEqual(@importedFiles, importedFiles)
      rm(@cacheDir)
      @importedFiles = importedFiles
      mkdir(@cacheDir)
      @writeJson(join(@cacheDir, 'imports.json'), {importedFiles})

  observeImportedFilePaths: (callback) ->
    importedPaths = []
    originalFsReadFileSync = fs.readFileSync
    fs.readFileSync = (filePath, args...) =>
      content = originalFsReadFileSync(filePath, args...)
      importedPaths.push({path: filePath, digest: @digestForContent(content)})
      content

    try
      callback()
    finally
      fs.readFileSync = originalFsReadFileSync

    importedPaths

  readJson: (filePath) -> JSON.parse(fs.readFileSync(filePath))

  writeJson: (filePath, object) -> fs.writeFileSync(filePath, JSON.stringify(object))

  digestForPath: (filePath) ->
    @digestForContent(fs.readFileSync(filePath))

  digestForContent: (content) ->
    crypto.createHash('SHA1').update(content).digest('hex')

  getCachePath: (filePath) ->
    cacheFile = "#{basename(filePath, extname(filePath))}.json"
    join(@cacheDir, 'content', dirname(filePath), cacheFile)

  getCachedCss: (filePath, digest) ->
    try
      cacheEntry = JSON.parse(fs.readFileSync(@getCachePath(filePath)))
    catch error
      return

    return unless digest is cacheEntry?.digest

    for {path, digest} in cacheEntry.imports
      try
        return if @digestForPath(path) isnt digest
      catch error
        return

    cacheEntry.css

  putCachedCss: (filePath, digest, css, imports) ->
    cachePath = @getCachePath(filePath)
    mkdir(dirname(cachePath))
    @writeJson(cachePath, {digest, css, imports, version: cacheVersion})

  parseLess: (filePath, less) ->
    css = null
    options = filename: filePath, syncImport: true, paths: @importPaths
    parser = new Parser(options)
    imports = @observeImportedFilePaths =>
      parser.parse less, (error, tree) =>
        if error?
          throw error
        else
          css = tree.toCSS()
    {imports, css}

  readFileSync: (filePath) ->
    less = fs.readFileSync(filePath, 'utf8')
    digest = @digestForContent(less)
    css = @getCachedCss(filePath, digest)
    unless css?
      {imports, css} = @parseLess(filePath, less)
      @putCachedCss(filePath, digest, css, imports)

    css
