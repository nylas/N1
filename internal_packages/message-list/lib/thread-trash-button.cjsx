_ = require 'underscore'
React = require 'react'
{Actions,
 DOMUtils,
 TaskFactory,
 AccountStore,
 FocusedPerspectiveStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ThreadTrashButton extends React.Component
  @displayName: "ThreadTrashButton"
  @containerRequired: false

  @propTypes:
    thread: React.PropTypes.object.isRequired

  render: =>
    allowed = FocusedPerspectiveStore.current().canMoveThreadsTo([@props.thread], 'trash')
    return <span /> unless allowed

    <button className="btn btn-toolbar btn-trash"
            style={order: -106}
            title="Move to Trash"
            onClick={@_onRemove}>
      <RetinaImg name="toolbar-trash.png" mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

  _onRemove: (e) =>
    return unless DOMUtils.nodeIsVisible(e.currentTarget)
    tasks = TaskFactory.tasksForMovingToTrash
      source: "Toolbar Button: Thread List"
      threads: [@props.thread]
    Actions.queueTasks(tasks)
    Actions.popSheet()
    e.stopPropagation()


module.exports = ThreadTrashButton
