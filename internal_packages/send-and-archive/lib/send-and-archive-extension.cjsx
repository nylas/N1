{React,
 Actions,
 Thread,
 DatabaseStore,
 TaskFactory,
 ComposerExtension,
 FocusedPerspectiveStore} = require 'nylas-exports'

{RetinaImg} = require 'nylas-component-kit'

class SendAndArchiveExtension extends ComposerExtension
  @sendActionConfig: ({draft}) ->
    if draft.threadId
      return {
        title: "Send and Archive"
        buttonTitle: "Send +"
        iconUrl: "nylas://send-and-archive/images/composer-archive@2x.png"
        onSend: @_sendAndArchive
      }
    else return null

  @_sendAndArchive: ({draft}) ->
    Actions.sendDraft(draft.clientId)
    DatabaseStore.modelify(Thread, [draft.threadId]).then (threads) =>
      tasks = TaskFactory.tasksForArchiving
        threads: threads
      Actions.queueTasks(tasks)

module.exports = SendAndArchiveExtension
