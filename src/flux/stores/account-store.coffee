_ = require 'underscore'
NylasStore = require 'nylas-store'
Actions = require '../actions'
Account = require '../models/account'
Utils = require '../models/utils'
DatabaseStore = require './database-store'


saveObjectsKey = "nylas.accounts"
saveTokensKey = "nylas.accountTokens"

###
Public: The AccountStore listens to changes to the available accounts in
the database and exposes the currently active Account via {::current}

Section: Stores
###
class AccountStore extends NylasStore

  constructor: ->
    @_load()
    @listenTo Actions.removeAccount, @_onRemoveAccount
    @listenTo Actions.updateAccount, @_onUpdateAccount
    @listenTo Actions.reorderAccount, @_onReorderAccount

    @_caches = {}

    NylasEnv.config.onDidChange saveTokensKey, (change) =>
      updatedTokens = change.newValue
      return if _.isEqual(updatedTokens, @_tokens)
      newAccountIds = _.keys(_.omit(updatedTokens, _.keys(@_tokens)))
      @_load()
      if newAccountIds.length > 0
        Actions.focusDefaultMailboxPerspectiveForAccounts([newAccountIds[0]])

    if NylasEnv.isComposerWindow() or NylasEnv.isWorkWindow()
      NylasEnv.config.onDidChange saveObjectsKey, => @_load()

  _load: =>
    @_caches = {}
    @_accounts = []
    for json in NylasEnv.config.get(saveObjectsKey) || []
      @_accounts.push((new Account).fromJSON(json))

    @_tokens = NylasEnv.config.get(saveTokensKey) || {}
    @_trigger()

  _trigger: ->
    for account in @_accounts
      if not account?.id
        err = new Error("An invalid account was added to `this._accounts`")
        NylasEnv.reportError(err)
        @_accounts = _.compact(@_accounts)
    @trigger()

  _save: =>
    NylasEnv.config.set(saveObjectsKey, @_accounts)
    NylasEnv.config.set(saveTokensKey, @_tokens)
    NylasEnv.config.save()

  # Inbound Events

  _onUpdateAccount: (id, updated) =>
    idx = _.findIndex @_accounts, (a) -> a.id is id
    account = @_accounts[idx]
    return if !account
    account = _.extend(account, updated)
    @_caches = {}
    @_accounts[idx] = account
    NylasEnv.config.set(saveObjectsKey, @_accounts)
    @_trigger()

  _onRemoveAccount: (id) =>
    idx = _.findIndex @_accounts, (a) -> a.id is id
    return if idx is -1

    delete @_tokens[id]
    @_caches = {}
    @_accounts.splice(idx, 1)
    @_save()

    if @_accounts.length is 0
      ipc = require('electron').ipcRenderer
      ipc.send('command', 'application:reset-config-and-relaunch')
    else
      @_trigger()
      Actions.focusDefaultMailboxPerspectiveForAccounts(@_accounts)

  _onReorderAccount: (id, newIdx) =>
    existingIdx = _.findIndex @_accounts, (a) -> a.id is id
    return if existingIdx is -1
    account = @_accounts[existingIdx]
    @_caches = {}
    @_accounts.splice(existingIdx, 1)
    @_accounts.splice(newIdx, 0, account)
    @_save()
    @_trigger()

  addAccountFromJSON: (json) =>
    if not json.email_address or not json.provider
      console.error("Returned account data is invalid", json)
      console.log JSON.stringify(json)
      throw new Error("Returned account data is invalid")

    @_load()
    @_tokens[json.id] = json.auth_token

    @_caches = {}
    existingIdx = _.findIndex @_accounts, (a) -> a.id is json.id
    if existingIdx is -1
      account = (new Account).fromJSON(json)
      @_accounts.push(account)
    else
      account = @_accounts[existingIdx]
      account.fromJSON(json)

    @_save()

    @_trigger()
    Actions.focusDefaultMailboxPerspectiveForAccounts([account.id])

  # Exposed Data

  # Private: Helper which caches the results of getter functions often needed
  # in the middle of React render cycles. (Performance critical!)

  _cachedGetter: (key, fn) ->
    @_caches[key] ?= fn()
    @_caches[key]

  # Public: Returns an {Array} of {Account} objects
  accounts: =>
    @_accounts

  accountsForItems: (items) =>
    accounts = {}
    items.forEach ({accountId}) =>
      accounts[accountId] ?= @accountForId(accountId)
    _.values(accounts)

  accountForItems: (items) =>
    accounts = @accountsForItems(items)
    return null if accounts.length > 1
    return accounts[0]

  # Public: Returns the {Account} for the given email address, or null.
  accountForEmail: (email) =>
    for account in @accounts()
      if Utils.emailIsEquivalent(email, account.emailAddress)
        return account
    for alias in @aliases()
      if Utils.emailIsEquivalent(email, alias.email)
        return @accountForId(alias.accountId)
    return null

  # Public: Returns the {Account} for the given account id, or null.
  accountForId: (id) =>
    @_cachedGetter "accountForId:#{id}", => _.findWhere(@_accounts, {id})

  aliases: =>
    @_cachedGetter "aliases", =>
      aliases = []
      for acc in @_accounts
        aliases.push(acc.me())
        for alias in acc.aliases
          aliasContact = acc.meUsingAlias(alias)
          aliasContact.isAlias = true
          aliases.push(aliasContact)
      return aliases

  aliasesFor: (accountsOrIds) =>
    ids = accountsOrIds.map (accOrId) ->
      if accOrId instanceof Account then accOrId.id else accOrId
    @aliases().filter((contact) -> contact.accountId in ids)

  # Public: Returns the currently active {Account}.
  current: =>
    throw new Error("AccountStore.current() has been deprecated.")

  # Private: This method is going away soon, do not rely on it.
  #
  tokenForAccountId: (id) =>
    @_tokens[id]

  # Private: Load fake data from a directory for taking nice screenshots
  #
  _importFakeData: (dir) =>
    fs = require 'fs-plus'
    path = require 'path'
    Message = require '../models/message'
    Account = require '../models/account'
    Thread = require '../models/thread'
    Label = require '../models/label'

    @_caches = {}

    labels = {}
    threads = []
    messages = []

    account = @accountForEmail('nora@nylas.com')
    unless account
      account = new Account()
      account.serverId = account.clientId
      account.emailAddress = "nora@nylas.com"
      account.organizationUnit = 'label'
      account.label = "Nora's Email"
      account.aliases = []
      account.name = "Nora"
      account.provider = "gmail"
      @_accounts.push(account)
      @_tokens[account.id] = 'nope'

    filenames = fs.readdirSync(path.join(dir, 'threads'))
    for filename in filenames
      threadJSON = fs.readFileSync(path.join(dir, 'threads', filename))
      threadMessages = JSON.parse(threadJSON).map (j) -> (new Message).fromJSON(j)
      threadLabels = []
      threadParticipants = []
      threadAttachment = false
      threadUnread = false

      for m in threadMessages
        m.accountId = account.id
        threadParticipants = threadParticipants.concat(m.participants())
        threadAttachment ||= m.files.length > 0
        threadUnread ||= m.unread

      threadParticipants = _.uniq threadParticipants, (p) -> p.email
      threadLabels = _.uniq threadLabels, (l) -> l.id

      lastMsg = _.last(threadMessages)
      thread = new Thread(
        accountId: account.id
        serverId: lastMsg.threadId
        clientId: lastMsg.threadId
        subject: lastMsg.subject
        lastMessageReceivedTimestamp: lastMsg.date
        hasAttachment: threadAttachment
        labels: threadLabels
        participants: threadParticipants
        unread: threadUnread
        snippet: lastMsg.snippet
        starred: lastMsg.starred
      )
      messages = messages.concat(threadMessages)
      threads.push(thread)

    downloadsDir = path.join(dir, 'downloads')
    if fs.existsSync(downloadsDir)
      for filename in fs.readdirSync(downloadsDir)
        fs.copySync(path.join(downloadsDir, filename), path.join(NylasEnv.getConfigDirPath(), 'downloads', filename))

    DatabaseStore.inTransaction (t) =>
      Promise.all([
        t.persistModel(account),
        t.persistModels(_.values(labels)),
        t.persistModels(messages),
        t.persistModels(threads)
      ])
    .then =>
      Actions.focusDefaultMailboxPerspectiveForAccounts([account.id])
    .then -> new Promise (resolve, reject) -> setTimeout(resolve, 1000)

module.exports = new AccountStore()
