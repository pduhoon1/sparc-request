class ModalStack
  # modalPlaceSelector: where to render the modal
  constructor: (modalPlaceSelector) ->
    @modalPlaceSelector = modalPlaceSelector

    # Where to keep track of previously and currently rendered modals.
    @stack = []

    # When closing a modal, remove it from @stack
    # and show previous modal, if one exists.
    $(document).on 'hide.bs.modal', modalPlaceSelector, (event) =>
      currentModal = @stack.pop()

      if @stack.length > 0
        # Prevent Bootstrap from closing our modal.
        # ModalStack or a js view will replace the modal for Bootstrap.
        event.preventDefault()
        event.stopImmediatePropagation()

        # Get previous modal
        modal = @stack.pop()

        @_addModal(modal, currentModal.reloadParent, false)

  # For internal use. Fetch the modal, and if reload is true, fetch it using
  # ajax. Otherwise, insert the saved markup.
  # If saveMarkup is true, it will save currently rendered modal's
  # markup.
  _addModal: (modal, reload, saveMarkup) =>
    stackLength = @stack.length

    # Save previous modal's markup for later; might need it.
    if stackLength > 0 and saveMarkup
      @stack[stackLength - 1].markup = $(@modalPlaceSelector).html()

    @stack.push modal
    if reload
      $.ajax(modal.ajaxOptions)
    else
      $(@modalPlaceSelector).html(modal.markup)

  # opts: Object you would normally pass to $.ajax
  #   to fetch modal HTML (or js to insert modal).
  #   So the modal must be fetched via ajax; the HTML can be returned
  #   as the 'modal' property of a JSON response, or if rendered by some js,
  #   then ModalStack will stay out of the way of that.
  #
  # valid options other than $.ajax options:
  # reloadParent: whether the modal predecessor should be reloaded
  #   via $.ajax (true, default) or we should retrieve its saved markup (false).
  addModal: (opts) =>
    # First, we figure the options we are going to pass to $.ajax
    # anytime we want to (re)display the modal.
    reloadParent = if "reloadParent" of opts
      opts.reloadParent
    else
      true
    
    delete opts.reloadParent

    # Get old success callback, if any
    success_cb_from_user = opts.success

    # ...and augment it
    opts.success = (data, status) =>
      # modal HTML passed in JSON object
      if typeof(data) == "object" and "modal" of data
        $(@modalPlaceSelector).html(data.modal)
        $(@modalPlaceSelector).modal("show")

      # If modal is being inserted into the page by js,
      # then we don't need to do anything.

      # Run success callback from user, if it is present
      if success_cb_from_user?
        success_cb_from_user(data)

    # $.ajax options finished. Push them onto stack and show the modal.
    @_addModal
      ajaxOptions: opts
      reloadParent: reloadParent,
      true, true

window.modalStack = new ModalStack("#modal_place")
