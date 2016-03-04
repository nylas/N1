_ = require 'underscore'
moment = require 'moment-timezone'
moment = require "moment"
React = require 'react'
{Utils} = require 'nylas-exports'

class MessageTimestamp extends React.Component
  @displayName: 'MessageTimestamp'
  @propTypes:
    date: React.PropTypes.object.isRequired,
    className: React.PropTypes.string,
    isDetailed: React.PropTypes.bool
    onClick: React.PropTypes.func

  shouldComponentUpdate: (nextProps, nextState) =>
    +nextProps.date isnt +@props.date or nextProps.isDetailed isnt @props.isDetailed

  render: =>
    msgDate = moment.tz(@props.date, Utils.timeZone)
    nowDate = @_today()
    formattedDate = @_formattedDate(msgDate, nowDate, @props.isDetailed)
    <div className={@props.className}
         onClick={@props.onClick}>{formattedDate}</div>

  _formattedDate: (msgDate, now, isDetailed) =>
    if isDetailed
      return msgDate.format "MMMM D, YYYY [at] h:mm A"
    else
      diff = now.diff(msgDate, 'days', true)
      isSameDay = now.isSame(msgDate, 'days')
      if diff < 1 and isSameDay
        if NylasEnv.config.get('core.reading.timeFormat') # Military (24 hour time) time added here -->
          return msgDate.format "HH:mm" # <--
        else
          return msgDate.format "h:mm A"
      if diff < 1.5 and not isSameDay
        timeAgo = msgDate.from now
        if NylasEnv.config.get('core.reading.timeFormat') # Military time added here -->
          monthAndDay = msgDate.format "HH:mm" # <--
        else
          monthAndDay = msgDate.format "h:mm A"
        return monthAndDay + " (" + timeAgo + ")"
      if diff >= 1.5 and diff < 365
        return msgDate.format "MMM D"
      if diff >= 365
        return msgDate.format "MMM D, YYYY"

  # Stubbable for testing. Returns a `moment`
  _today: -> moment.tz(Utils.timeZone)




module.exports = MessageTimestamp
