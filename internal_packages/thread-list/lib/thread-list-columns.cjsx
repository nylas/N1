_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
moment = require 'moment'

{ListTabular,
 RetinaImg,
 MailLabelSet,
 MailImportantIcon,
 InjectedComponentSet} = require 'nylas-component-kit'

{Thread, FocusedPerspectiveStore, Utils, DateUtils} = require 'nylas-exports'

{ThreadArchiveQuickAction,
 ThreadTrashQuickAction} = require './thread-list-quick-actions'

ThreadListParticipants = require './thread-list-participants'
ThreadListStore = require './thread-list-store'
ThreadListIcon = require './thread-list-icon'

# Get and format either last sent or last received timestamp depending on thread-list being viewed
TimestampComponentForPerspective = (thread) ->
  if FocusedPerspectiveStore.current().isSent()
    rawTimestamp = thread.lastMessageSentTimestamp
  else
    rawTimestamp = thread.lastMessageReceivedTimestamp
  timestamp = DateUtils.shortTimeString(rawTimestamp)
  <span className="timestamp">{timestamp}</span>

subject = (subj) ->
  if (subj ? "").trim().length is 0
    return <span className="no-subject">(No Subject)</span>
  else if subj.split(/([\uD800-\uDBFF][\uDC00-\uDFFF])/g).length > 1
    subjComponents = []
    subjParts = subj.split /([\uD800-\uDBFF][\uDC00-\uDFFF])/g
    for part in subjParts
      if part.match /([\uD800-\uDBFF][\uDC00-\uDFFF])/g
        subjComponents.push <span className="emoji">{part}</span>
      else
        subjComponents.push <span>{part}</span>
    return subjComponents
  else
    return subj


c1 = new ListTabular.Column
  name: "★"
  resolver: (thread) =>
    [
      <ThreadListIcon key="thread-list-icon" thread={thread} />
      <MailImportantIcon
        key="mail-important-icon"
        thread={thread}
        showIfAvailableForAnyAccount={true} />
      <InjectedComponentSet
        key="injected-component-set"
        inline={true}
        containersRequired={false}
        matching={role: "ThreadListIcon"}
        className="thread-injected-icons"
        exposedProps={thread: thread}/>
    ]

c2 = new ListTabular.Column
  name: "Participants"
  width: 200
  resolver: (thread) =>
    hasDraft = _.find (thread.metadata ? []), (m) -> m.draft
    if hasDraft
      <div style={display: 'flex'}>
        <ThreadListParticipants thread={thread} />
        <RetinaImg name="icon-draft-pencil.png"
                   className="draft-icon"
                   mode={RetinaImg.Mode.ContentPreserve} />
      </div>
    else
      <ThreadListParticipants thread={thread} />

c3 = new ListTabular.Column
  name: "Message"
  flex: 4
  resolver: (thread) =>
    attachment = false
    metadata = (thread.metadata ? [])

    hasAttachments = thread.hasAttachments and metadata.find (m) -> Utils.showIconForAttachments(m.files)
    if hasAttachments
      attachment = <div className="thread-icon thread-icon-attachment"></div>

    <span className="details">
      <MailLabelSet thread={thread} />
      <span className="subject">{subject(thread.subject)}</span>
      <span className="snippet">{thread.snippet}</span>
      {attachment}
    </span>

c4 = new ListTabular.Column
  name: "Date"
  resolver: (thread) =>
    TimestampComponentForPerspective(thread)

c5 = new ListTabular.Column
  name: "HoverActions"
  resolver: (thread) =>
    <div className="inner">
      <InjectedComponentSet
        key="injected-component-set"
        inline={true}
        containersRequired={false}
        children=
        {[
          <ThreadTrashQuickAction key="thread-trash-quick-action" thread={thread} />
          <ThreadArchiveQuickAction key="thread-archive-quick-action" thread={thread} />
        ]}
        matching={role: "ThreadListQuickAction"}
        className="thread-injected-quick-actions"
        exposedProps={thread: thread}/>
    </div>

cNarrow = new ListTabular.Column
  name: "Item"
  flex: 1
  resolver: (thread) =>
    pencil = false
    attachment = false
    metadata = (thread.metadata ? [])

    hasAttachments = thread.hasAttachments and metadata.find (m) -> Utils.showIconForAttachments(m.files)
    if hasAttachments
      attachment = <div className="thread-icon thread-icon-attachment"></div>

    hasDraft = _.find metadata, (m) -> m.draft
    if hasDraft
      pencil = <RetinaImg name="icon-draft-pencil.png" className="draft-icon" mode={RetinaImg.Mode.ContentPreserve} />

    # TODO We are limiting the amount on injected icons in narrow mode to 1
    # until we revisit the UI to accommodate more icons
    <div style={display: 'flex', alignItems: 'flex-start'}>
      <div className="icons-column">
        <ThreadListIcon thread={thread} />
        <InjectedComponentSet
          inline={true}
          matchLimit={1}
          direction="column"
          containersRequired={false}
          key="injected-component-set"
          exposedProps={thread: thread}
          matching={role: "ThreadListIcon"}
          className="thread-injected-icons"
        />
        <MailImportantIcon
          thread={thread}
          showIfAvailableForAnyAccount={true}
        />
      </div>
      <div className="thread-info-column">
        <div className="participants-wrapper">
          <ThreadListParticipants thread={thread} />
          {pencil}
          <span style={flex:1}></span>
          {attachment}
          {TimestampComponentForPerspective(thread)}
        </div>
        <div className="subject">{subject(thread.subject)}</div>
        <div className="snippet-and-labels">
          <div className="snippet">{thread.snippet}&nbsp;</div>
          <div style={flex: 1, flexShrink: 1}></div>
          <MailLabelSet thread={thread} />
        </div>
      </div>
    </div>

module.exports =
  Narrow: [cNarrow]
  Wide: [c1, c2, c3, c4, c5]
