{Actions, LaunchServices} = require 'nylas-exports'

NOTIF_ACTION_YES = 'mailto:set-default-yes'
NOTIF_ACTION_NO = 'mailto:set-default-no'

NOTIF_SETTINGS_KEY = 'nylas.mailto.prompted-about-default'

module.exports =
  activate: (@state) ->
    @services = new LaunchServices()

    # We can't do anything unless they're on Mac OS X
    return unless @services.available()

    # We shouldn't ask if they've already said No
    return if atom.config.get(NOTIF_SETTINGS_KEY) is true

    @services.isRegisteredForURLScheme 'mailto', (registered) =>
      # Prompt them to make Nylas their default client
      unless registered
        @_unlisten = Actions.notificationActionTaken.listen(@_onNotificationActionTaken, @)
        Actions.postNotification
          type: 'info',
          sticky: true
          message: "Thanks for trying out N1! Would you like to make it your default mail client?",
          icon: 'fa-inbox',
          actions: [{
            label: 'Not Now'
            dismisses: true
            id: NOTIF_ACTION_NO
          },{
            label: 'Yes'
            dismisses: true
            default: true
            id: NOTIF_ACTION_YES
          }]

  deactivate: ->
    @_unlisten?()

  serialize: -> @state

  _onNotificationActionTaken: ({notification, action}) ->
    if action.id is NOTIF_ACTION_YES
      @services.registerForURLScheme 'mailto', (err) ->
        console.log(err) if err

    if action.id is NOTIF_ACTION_NO
      atom.config.set(NOTIF_SETTINGS_KEY, true)
