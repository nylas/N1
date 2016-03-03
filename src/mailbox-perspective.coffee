_ = require 'underscore'

Utils = require './flux/models/utils'
TaskFactory = require './flux/tasks/task-factory'
AccountStore = require './flux/stores/account-store'
CategoryStore = require './flux/stores/category-store'
DatabaseStore = require './flux/stores/database-store'
OutboxStore = require './flux/stores/outbox-store'
SearchSubscription = require './search-subscription'
ThreadCountsStore = require './flux/stores/thread-counts-store'
MutableQuerySubscription = require './flux/models/mutable-query-subscription'
Thread = require './flux/models/thread'
Actions = require './flux/actions'

# This is a class cluster. Subclasses are not for external use!
# https://developer.apple.com/library/ios/documentation/General/Conceptual/CocoaEncyclopedia/ClassClusters/ClassClusters.html

class MailboxPerspective

  # Factory Methods
  @forNothing: ->
    new EmptyMailboxPerspective()

  @forDrafts: (accountsOrIds) ->
    new DraftsMailboxPerspective(accountsOrIds)

  @forCategory: (category) ->
    return @forNothing() unless category
    new CategoryMailboxPerspective([category])

  @forCategories: (categories) ->
    return @forNothing() if categories.length is 0
    new CategoryMailboxPerspective(categories)

  @forStandardCategories: (accountsOrIds, names...) ->
    categories = CategoryStore.getStandardCategories(accountsOrIds, names...)
    @forCategories(categories)

  @forStarred: (accountsOrIds) ->
    new StarredMailboxPerspective(accountsOrIds)

  @forSearch: (accountsOrIds, query) ->
    new SearchMailboxPerspective(accountsOrIds, query)

  @forInbox: (accountsOrIds) =>
    @forStandardCategories(accountsOrIds, 'inbox')

  @fromJSON: (json) =>
    try
      if json.type is CategoryMailboxPerspective.name
        categories = JSON.parse(json.serializedCategories, Utils.registeredObjectReviver)
        return @forCategories(categories)
      else if json.type is SearchMailboxPerspective.name
        return @forSearch(json.accountIds, json.searchQuery)
      else if json.type is StarredMailboxPerspective.name
        return @forStarred(json.accountIds)
      else if json.type is DraftsMailboxPerspective.name
        return @forDrafts(json.accountIds)
      else
        return null
    catch error
      NylasEnv.reportError(new Error("Could not restore mailbox perspective: #{error}"))
      return null

  # Instance Methods

  constructor: (@accountIds) ->
    unless @accountIds instanceof Array and _.every(@accountIds, _.isString)
      throw new Error("#{@constructor.name}: You must provide an array of string `accountIds`")
    @

  toJSON: =>
    return {accountIds: @accountIds, type: @constructor.name}

  isEqual: (other) =>
    return false unless other and @constructor is other.constructor
    return false unless other.name is @name
    return false unless _.isEqual(@accountIds, other.accountIds)
    true

  categories: =>
    []

  categoriesSharedName: =>
    cats = @categories()
    return null unless cats and cats.length > 0
    name = cats[0].name
    return null unless _.every cats, (cat) -> cat.name is name
    return name

  category: =>
    return null unless @categories().length is 1
    return @categories()[0]

  threads: =>
    throw new Error("threads: Not implemented in base class.")

  unreadCount: =>
    0

  # Public:
  # - accountIds {Array} Array of unique account ids associated with the threads
  # that want to be included in this perspective
  #
  # Returns true if the accountIds are part of the current ids, or false
  # otherwise. This means that it checks if I am moving trying to move threads
  # betwee the same set of accounts:
  #
  # E.g.:
  # perpective = Starred for accountIds: a1, a2
  # thread1 has accountId a3
  # thread2 has accountId a2
  #
  # perspective.canReceiveThreads([a2, a3]) -> false -> I cant move those threads to Starred
  # perspective.canReceiveThreads([a2]) -> true -> I can move that thread to # Starred
  canReceiveThreads: (accountIds) =>
    return false unless accountIds and accountIds.length > 0
    incomingIdsInCurrent = _.difference(accountIds, @accountIds).length is 0
    return incomingIdsInCurrent

  receiveThreads: (threadsOrIds) =>
    throw new Error("receiveThreads: Not implemented in base class.")

  removeThreads: (threadsOrIds) =>
    # Don't throw an error here because we just want it to be a no op if not
    # implemented
    return

  # Whether or not the current MailboxPerspective can "archive" or "trash"
  # Subclasses should call `super` if they override these methods
  canArchiveThreads: =>
    for aid in @accountIds
      return false unless CategoryStore.getArchiveCategory(aid)
    return true

  canTrashThreads: =>
    for aid in @accountIds
      return false unless CategoryStore.getTrashCategory(aid)
    return true

  isInbox: =>
    false

class SearchMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds, @searchQuery) ->
    super(@accountIds)

    unless _.isString(@searchQuery)
      throw new Error("SearchMailboxPerspective: Expected a `string` search query")

    @

  toJSON: =>
    json = super
    json.searchQuery = @searchQuery
    json

  isEqual: (other) =>
    super(other) and other.searchQuery is @searchQuery

  threads: =>
    new SearchSubscription(@searchQuery, @accountIds)

  canReceiveThreads: =>
    false

  canArchiveThreads: =>
    false

  canTrashThreads: =>
    false


class DraftsMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds) ->
    super(@accountIds)
    @name = "Drafts"
    @iconName = "drafts.png"
    @drafts = true # The DraftListStore looks for this
    @

  fromJSON: =>
    {type: @constructor.name, accountIds: @accountIds}

  threads: =>
    null

  unreadCount: =>
    count = 0
    count += OutboxStore.itemsForAccount(aid).length for aid in @accountIds
    count

  canReceiveThreads: =>
    false

class StarredMailboxPerspective extends MailboxPerspective
  constructor: (@accountIds) ->
    super(@accountIds)
    @name = "Starred"
    @iconName = "starred.png"
    @

  threads: =>
    query = DatabaseStore.findAll(Thread).where([
      Thread.attributes.accountId.in(@accountIds),
      Thread.attributes.starred.equal(true)
    ]).limit(0)

    return new MutableQuerySubscription(query, {asResultSet: true})

  canReceiveThreads: =>
    super

  receiveThreads: (threadsOrIds) =>
    ChangeStarredTask = require './flux/tasks/change-starred-task'
    task = new ChangeStarredTask({threads:threadsOrIds, starred: true})
    Actions.queueTask(task)

  removeThreads: (threadsOrIds) =>
    unless threadsOrIds instanceof Array
      throw new Error("removeThreads: you must pass an array of threads or thread ids")
    task = TaskFactory.taskForInvertingStarred(threads: threadsOrIds)
    Actions.queueTask(task)

class EmptyMailboxPerspective extends MailboxPerspective
  constructor: ->
    @accountIds = []

  threads: =>
    query = DatabaseStore.findAll(Thread).where(accountId: -1).limit(0)
    return new MutableQuerySubscription(query, {asResultSet: true})

  canReceiveThreads: =>
    false

  canArchiveThreads: =>
    false

  canTrashThreads: =>
    false


class CategoryMailboxPerspective extends MailboxPerspective
  constructor: (@_categories) ->
    super(_.uniq(_.pluck(@_categories, 'accountId')))

    if @_categories.length is 0
      throw new Error("CategoryMailboxPerspective: You must provide at least one category.")

    # Note: We pick the display name and icon assuming that you won't create a
    # perspective with Inbox and Sent or anything crazy like that... todo?
    @name = @_categories[0].displayName
    if @_categories[0].name
      @iconName = "#{@_categories[0].name}.png"
    else
      @iconName = AccountStore.accountForId(@accountIds[0]).categoryIcon()

    @

  toJSON: =>
    json = super
    json.serializedCategories = JSON.stringify(@_categories, Utils.registeredObjectReplacer)
    json

  isEqual: (other) =>
    super(other) and _.isEqual(_.pluck(@categories(), 'id'), _.pluck(other.categories(), 'id'))

  threads: =>
    query = DatabaseStore.findAll(Thread)
      .where([Thread.attributes.categories.containsAny(_.pluck(@categories(), 'id'))])
      .limit(0)

    if @_categories.length > 1 and @accountIds.length < @_categories.length
      # The user has multiple categories in the same account selected, which
      # means our result set could contain multiple copies of the same threads
      # (since we do an inner join) and we need SELECT DISTINCT. Note that this
      # can be /much/ slower and we shouldn't do it if we know we don't need it.
      query.distinct()

    return new MutableQuerySubscription(query, {asResultSet: true})

  unreadCount: =>
    sum = 0
    for cat in @_categories
      sum += ThreadCountsStore.unreadCountForCategoryId(cat.id)
    sum

  categories: =>
    @_categories

  isInbox: =>
    @categoriesSharedName() is 'inbox'

  canReceiveThreads: =>
    super and not _.any @_categories, (c) -> c.isLockedCategory()

  canArchiveThreads: =>
    for cat in @_categories
      return false if cat.name in ["archive", "all", "sent"]
    super

  canTrashThreads: =>
    for cat in @_categories
      return false if cat.name in ["trash", "sent"]
    super

  receiveThreads: (threadsOrIds) =>
    FocusedPerspectiveStore = require './flux/stores/focused-perspective-store'
    currentCategories = FocusedPerspectiveStore.current().categories()

    # This assumes that the we don't have more than one category per accountId
    # attached to this perspective
    DatabaseStore.modelify(Thread, threadsOrIds).then (threads) =>
      tasks = TaskFactory.tasksForApplyingCategories
        threads: threads
        categoriesToRemove: (accountId) -> _.filter(currentCategories, _.matcher({accountId}))
        categoryToAdd: (accountId) => _.findWhere(@_categories, {accountId})
      Actions.queueTasks(tasks)

  removeThreads: (threadsOrIds) =>
    unless threadsOrIds instanceof Array
      throw new Error("removeThreads: you must pass an array of threads or thread ids")

    DatabaseStore.modelify(Thread, threadsOrIds).then (threads) =>
      isFinishedCategory = _.any @_categories, (cat) ->
        cat.name in ['trash', 'archive', 'all']

      if isFinishedCategory
        Actions.queueTasks(TaskFactory.tasksForMovingToInbox({
          threads: threads,
          fromPerspective: @
        }))
      else
        Actions.queueTasks(TaskFactory.tasksForRemovingCategories({
          threads: threads,
          categories: @categories(),
          moveToFinishedCategory: @isInbox()
        }))

module.exports = MailboxPerspective
