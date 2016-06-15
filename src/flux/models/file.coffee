path = require 'path'
Model = require './model'
Actions = require '../actions'
Attributes = require '../attributes'
_ = require 'underscore'
RegExpUtils = null

###
Public: File model represents a File object served by the Nylas Platform API.
For more information about Files on the Nylas Platform, read the
[Files API Documentation](https://nylas.com/cloud/docs#files)

## Attributes

`filename`: {AttributeString} The display name of the file. Queryable.

`size`: {AttributeNumber} The size of the file, in bytes.

`contentType`: {AttributeString} The content type of the file (ex: `image/png`)

`contentId`: {AttributeString} If this file is an inline attachment, contentId
is a string that matches a cid:<value> found in the HTML body of a {Message}.

This class also inherits attributes from {Model}

Section: Models
###
class File extends Model

  @attributes: _.extend {}, Model.attributes,
    'filename': Attributes.String
      modelKey: 'filename'
      jsonKey: 'filename'
      queryable: true

    'size': Attributes.Number
      modelKey: 'size'
      jsonKey: 'size'

    'contentType': Attributes.String
      modelKey: 'contentType'
      jsonKey: 'content_type'

    'messageIds': Attributes.Collection
      modelKey: 'messageIds'
      jsonKey: 'message_ids'
      itemClass: String

    'contentId': Attributes.String
      modelKey: 'contentId'
      jsonKey: 'content_id'

  # Public: Files can have empty names, or no name. `displayName` returns the file's
  # name if one is present, and falls back to appropriate default name based on
  # the contentType. It will always return a non-empty string.
  #
  displayName: ->
    defaultNames = {
      'text/calendar': "Event.ics",
      'image/png': 'Unnamed Image.png'
      'image/jpg': 'Unnamed Image.jpg'
      'image/jpeg': 'Unnamed Image.jpg'
    }
    if @filename and @filename.length
      return @filename
    else if defaultNames[@contentType]
      return defaultNames[@contentType]
    else
      return "Unnamed Attachment"

  safeDisplayName: ->
    RegExpUtils ?= require '../../regexp-utils'
    return @displayName().replace(RegExpUtils.illegalPathCharactersRegexp(), '-')

  # Public: Returns the file extension that should be used for this file.
  # Note that asking for the displayExtension is more accurate than trying to read
  # the extension directly off the filename. The returned extension may be based
  # on contentType and is always lowercase.
  #
  # Returns the extension without the leading '.' (ex: 'png', 'pdf')
  #
  displayExtension: ->
    path.extname(@displayName().toLowerCase())[1..-1]

  displayFileSize: (bytes = @size) ->
    threshold = 1000000000
    units = ['B', 'KB', 'MB', 'GB']
    idx = units.length - 1

    result = bytes / threshold
    while result < 1 and idx >= 0
      threshold /= 1000
      result = bytes / threshold
      idx--

    # parseFloat will remove trailing zeros
    decimalPoints = if idx >= 2 then 1 else 0
    rounded = parseFloat(result.toFixed(decimalPoints))
    return "#{rounded} #{units[idx]}"

module.exports = File
