_ = require 'underscore'
Task = require './task'
Thread = require '../models/thread'
Category = require '../models/category'
Message = require '../models/message'
DatabaseStore = require '../stores/database-store'
ChangeMailTask = require './change-mail-task'
SyncbackCategoryTask = require './syncback-category-task'

# Public: Create a new task to apply labels to a message or thread.
#
# Takes an options object of the form:
#   - folder: The {Folder} or {Folder} IDs to move to
#   - threads: An array of {Thread}s or {Thread} IDs
#   - threads: An array of {Message}s or {Message} IDs
#   - undoData: Since changing the folder is a destructive action,
#   undo tasks need to store the configuration of what folders messages
#   were in. When creating an undo task, we fill this parameter with
#   that configuration
#
class ChangeFolderTask extends ChangeMailTask

  constructor: ({@folder, @taskDescription}={}) ->
    super

  label: ->
    if @folder
      "Moving to #{@folder.displayName}…"
    else
      "Moving to folder…"

  description: ->
    return @taskDescription if @taskDescription
    folderText = ""
    if @folder instanceof Category
      folderText = " to #{@folder.displayName}"

    if @threads.length > 0
      if @threads.length > 1
        return "Moved " + @threads.length + " threads#{folderText}"
      return "Moved 1 thread#{folderText}"
    else if @messages.length > 0
      if @messages.length > 1
        return "Moved " + @messages.length + "messages#{folderText}"
      return "Moved 1 message#{folderText}"
    else
      return "Moved objects#{folderText}"

  isDependentTask: (other) -> other instanceof SyncbackCategoryTask

  performLocal: ->
    if not @folder
      return Promise.reject(new Error("Must specify a `folder`"))
    if @threads.length > 0 and @messages.length > 0
      return Promise.reject(new Error("ChangeFoldersTask: You can move `threads` or `messages` but not both"))
    if @threads.length is 0 and @messages.length is 0
      return Promise.reject(new Error("ChangeFoldersTask: You must provide a `threads` or `messages` Array of models or IDs."))

    # Convert arrays of IDs or models to models.
    # modelify returns immediately if no work is required
    Promise.props(
      folder: DatabaseStore.modelify(Category, [@folder])
      threads: DatabaseStore.modelify(Thread, @threads)
      messages: DatabaseStore.modelify(Message, @messages)

    ).then ({folder, threads, messages}) =>
      # Remove any objects we weren't able to find. This can happen pretty easily
      # if you undo an action and other things have happened.
      @folder = folder[0]
      @threads = _.compact(threads)
      @messages = _.compact(messages)

      if not @folder
        return Promise.reject(new Error("The specified folder could not be found."))

      # The base class does the heavy lifting and calls changesToModel
      return super

  processNestedMessages: ->
    false

  changesToModel: (model) ->
    if model instanceof Thread
      {categories: [@folder]}
    else
      {categories: [@folder]}

  requestBodyForModel: (model) ->
    if model instanceof Thread
      folder: model.folders[0]?.id || null
    else
      folder: model.folder?.id || null

module.exports = ChangeFolderTask
