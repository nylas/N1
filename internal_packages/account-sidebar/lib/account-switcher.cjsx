React = require 'react'
{Actions, AccountStore, Label, ThreadCountsStore} = require("nylas-exports")
crypto = require 'crypto'
{RetinaImg} = require 'nylas-component-kit'
{Categories} = require 'nylas-observables'
classNames = require 'classnames'

class AccountSwitcher extends React.Component
  @displayName: 'AccountSwitcher'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 210

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @state.showing = false

    @_inboxCategoryCache = {}

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push AccountStore.listen @_onStoreChange
    @unsubscribers.push Categories.forAllAccounts().sort().subscribe @_onCategoriesChanged

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  render: =>
    return false unless @state.account

    <div id="account-switcher"
         tabIndex={-1}
         onBlur={@_onBlur}
         ref="button">
      {@_renderAccounts()}
      {@_renderNewAccountOption()}
    </div>

  _renderPrimaryItem: =>
    label = @state.account.label.trim()
    <div className="item primary-item" onClick={@_toggleDropdown}>
      {@_renderGravatarForAccount(@state.account)}
      <div style={float: 'right', marginTop: -2}>
        <RetinaImg className="toggle"
                   name="account-switcher-dropdown.png"
                   mode={RetinaImg.Mode.ContentDark} />
      </div>
      <div className="name" style={lineHeight: "110%"}>
        {label}
      </div>
      <div style={clear: "both"}></div>
    </div>

  _renderAccounts: =>
    @state.accounts.map(@_renderAccount)

  _renderAccount: (account) =>
    email = account.emailAddress.trim().toLowerCase()
    label = account.label.trim()
    unreadCount = ThreadCountsStore.unreadCountForCategoryId @_inboxCategoryCache[account.serverId]
    classes = classNames
      "active": account is @state.account
      "item": true
      "secondary-item": true

    <div className={classes} onClick={ => @_onSwitchAccount(account)} key={email}>
      {@_renderGravatarForAccount(account)}
      {@_renderUnreadCount(unreadCount)}
      <div className="name" style={lineHeight: "110%"}>{label}</div>
      <div style={clear: "both"}></div>
    </div>

  _renderNewAccountOption: =>
    <div className="item secondary-item new-account-option"
         onClick={@_onManageAccounts}
         tabIndex={999}>
      <div style={float: 'left'}>
        <RetinaImg name="icon-accounts-addnew.png"
                   fallback="ic-settings-account-imap.png"
                   mode={RetinaImg.Mode.ContentPreserve}
                   style={width: 28, height: 28, marginTop: -10} />
      </div>
      <div className="name" style={lineHeight: "110%", textTransform: 'none'}>
        Manage accounts&hellip;
      </div>
      <div style={clear: "both"}></div>
    </div>

  _renderDropdown: =>
    <div className="dropdown">
      <div className="inner">
        {@state.accounts.map(@_renderAccount)}
        {@_renderNewAccountOption()}
      </div>
    </div>

  _renderGravatarForAccount: (account) =>
    email = account.emailAddress.trim().toLowerCase()
    hash = crypto.createHash('md5').update(email, 'utf8').digest('hex')
    url = "url(http://www.gravatar.com/avatar/#{hash}?d=blank&s=56)"

    <div style={float: 'left', position: "relative"}>
      <div className="gravatar" style={backgroundImage:url}></div>
      <RetinaImg name={"ic-settings-account-#{account.provider}@2x.png"}
                 style={width: 28, height: 28, marginTop: -10}
                 fallback="ic-settings-account-imap.png"
                 mode={RetinaImg.Mode.ContentPreserve} />
    </div>

  _renderUnreadCount: (unreadCount) =>
    return false unless unreadCount
    className = 'item-count-box inbox'
    <div className={className}>{unreadCount}</div>

  _toggleDropdown: =>
    @setState showing: !@state.showing

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _onCategoriesChanged: (categories) =>
    return unless categories

    @_inboxCategoryCache = {}
    for category in categories
      @_inboxCategoryCache[category.accountId] = category.id if category.name is 'inbox'

  _onBlur: (e) =>
    target = e.nativeEvent.relatedTarget
    if target? and React.findDOMNode(@refs.button).contains(target)
      return
    @setState(showing: false)

  _onSwitchAccount: (account) =>
    Actions.selectAccount(account.id)
    @setState(showing: false)

  _onManageAccounts: =>
    Actions.switchPreferencesTab('Accounts')
    Actions.openPreferences()

    @setState(showing: false)

  _getStateFromStores: =>
    accounts: AccountStore.items()
    account:  AccountStore.current()

module.exports = AccountSwitcher
