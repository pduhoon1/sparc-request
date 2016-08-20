class ModalStack
  # modalPlaceSelector - where to render the modal
  constructor: (modalPlaceSelector) ->
    @modalPlaceSelector = modalPlaceSelector

    # Where to keep track of previously rendered modals.
    # Push $.ajax options here, so that previously displayed modals
    # can be re-rendered.
    @stack = []

    # When closing a modal, remove its ajax options from @stack
    # and show previous modal, if one exists.
    $(document).on 'hidden.bs.modal', modalPlaceSelector, =>
      @stack.pop()
      if @stack.length > 0
        ajaxOptions = @stack.pop()
        @_showModal(ajaxOptions)

  # For internal use. Fetch the modal using ajaxOptions, which are
  # pushed onto the stack.
  _showModal: (ajaxOptions) =>
    @stack.push(ajaxOptions)
    $.ajax(ajaxOptions)

  # ajaxOptions is the object you would normally pass to $.ajax
  # to fetch modal HTML (or js to insert modal).
  # So the modal has to be fetched via ajax; the HTML can be returned
  # as the 'modal' property of a JSON response, or if rendered by some js,
  # then ModalStack will stay out of the way of that.
  addModal: (ajaxOptions) =>
    # First, we figure the options we are going to pass to $.ajax
    # anytime we want to (re)display the modal.

    # Get old success callback, if any
    success_cb_from_user = ajaxOptions["success"]

    # ...and augment it
    ajaxOptions["success"] = (data, status) =>
      # modal HTML passed in JSON object
      if typeof(data) == 'object' and "modal" of data
        $(@modalPlaceSelector).html(data.modal)
        $(@modalPlaceSelector).modal('show')

      # If modal is being inserted into the page by js,
      # then we don't need to do anything.

      # Run success callback from user, if it is present
      if success_cb_from_user?
        success_cb_from_user(data)

    # $.ajax options finished. Push them onto stack and show the modal.
    @_showModal(ajaxOptions)

window.modalStack = new ModalStack('#modal_place')
