classNames = require 'classnames'
React = require 'react'

class DeveloperBarCurlItem extends React.Component
  @displayName: 'DeveloperBarCurlItem'

  render: =>
    classes = classNames
      "item": true
      "error-code": @_isError()
    <div className={classes}>
      <div className="code">{@props.item.statusCode}{@_errorMessage()}</div>
      <span className="timestamp">{@props.item.startMoment.format("HH:mm:ss")}&nbsp;&nbsp;</span>
      <a onClick={@_onRunCommand}>Run</a>
      <a onClick={@_onCopyCommand}>Copy</a>
      {@props.item.command}
    </div>

  shouldComponentUpdate: (nextProps) =>
    return @props.item isnt nextProps.item

  _onCopyCommand: =>
    clipboard = require('electron').clipboard
    clipboard.writeText(@props.item.commandWithAuth)

  _isError: ->
    return false if @props.item.statusCode is "pending"
    return not (parseInt(@props.item.statusCode) <= 399)

  _errorMessage: ->
    if (@props.item.errorMessage ? "").length > 0
      return " | #{@props.item.errorMessage}"
    else
      return ""

  _onRunCommand: =>
    curlFile = "#{NylasEnv.getConfigDirPath()}/curl.command"
    fs = require 'fs-plus'
    if fs.existsSync(curlFile)
      fs.unlinkSync(curlFile)
    fs.writeFileSync(curlFile, @props.item.commandWithAuth)
    fs.chmodSync(curlFile, '777')
    {shell} = require 'electron'
    shell.openItem(curlFile)


module.exports = DeveloperBarCurlItem
