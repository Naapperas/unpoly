###**
Forms
=====
  
Unpoly comes with functionality to [submit](/form-up-target) and [validate](/input-up-validate)
forms without leaving the current page. This means you can replace page fragments,
open dialogs with sub-forms, etc. all without losing form state.

@module up.form
###
up.form = do ->
  
  u = up.util
  e = up.element

  ATTRIBUTES_SUGGESTING_SUBMIT = ['[up-submit]', '[up-target]', '[up-layer]', '[up-mode]', '[up-transition]']

  ###**
  Sets default options for form submission and validation.

  @property up.form.config
  @param {number} [config.observeDelay=0]
    The number of miliseconds to wait before [`up.observe()`](/up.observe) runs the callback
    after the input value changes. Use this to limit how often the callback
    will be invoked for a fast typist.
  @param {Array<string>} [config.submitSelectors=['form[up-target]', 'form[up-follow]']]
    An array of CSS selectors matching forms that will be [submitted by Unpoly](/up.submit).
  @param {Array<string>} [config.validateTargets=['[up-fieldset]:has(&)', 'fieldset:has(&)', 'label:has(&)', 'form:has(&)']]
    An array of CSS selectors that are searched around a form field
    that wants to [validate](/up.validate). The first matching selector
    will be updated with the validation messages from the server.

    By default this looks for a `<fieldset>`, `<label>` or `<form>`
    around the validating input field.
  @param {string} [config.fieldSelectors]
    An array of CSS selectors that represent form fields, such as `input` or `select`.
  @param {string} [config.submitButtonSelectors]
    An array of CSS selectors that represent submit buttons, such as `input[type=submit]`.
  @stable
  ###
  config = new up.Config ->
    validateTargets: ['[up-fieldset]:has(&)', 'fieldset:has(&)', 'label:has(&)', 'form:has(&)']
    fieldSelectors: ['select', 'input:not([type=submit]):not([type=image])', 'button[type]:not([type=submit])', 'textarea'],
    submitSelectors: up.link.combineFollowableSelectors(['form'], ATTRIBUTES_SUGGESTING_SUBMIT)
    submitButtonSelectors: ['input[type=submit]', 'input[type=image]', 'button[type=submit]', 'button:not([type])']
    observeDelay: 0

  fullSubmitSelector = ->
    config.submitSelectors.join(',')

  abortScheduledValidate = null

  reset = ->
    config.reset()

  ###**
  @function up.form.fieldSelector
  @internal
  ###
  fieldSelector = (suffix = '') ->
    config.fieldSelectors.map((field) -> field + suffix).join(',')

  ###**
  Returns a list of form fields within the given element.

  You can configure what Unpoly considers a form field by adding CSS selectors to the
  `up.form.config.fieldSelectors` array.

  If the given element is itself a form field, a list of that given element is returned.

  @function up.form.fields
  @param {Element|jQuery} root
    The element to scan for contained form fields.

    If the element is itself a form field, a list of that element is returned.
  @return {NodeList<Element>|Array<Element>}
  @experimental
  ###
  findFields = (root) ->
    root = e.get(root) # unwrap jQuery
    fields = e.subtree(root, fieldSelector())

    # If findFields() is called with an entire form, gather fields outside the form
    # element that are associated with the form (through <input form="id-of-form">, which
    # is an HTML feature.)
    if e.matches(root, 'form[id]')
      outsideFieldSelector = fieldSelector(e.attributeSelector('form', root.getAttribute('id')))
      outsideFields = e.all(outsideFieldSelector)
      fields.push(outsideFields...)
      fields = u.uniq(fields)

    fields

  ###**
  @function up.form.submittingButton
  @param {Element} form
  @internal
  ###
  submittingButton = (form) ->
    selector = submitButtonSelector()
    focusedElement = document.activeElement
    if focusedElement && e.matches(focusedElement, selector) && form.contains(focusedElement)
      return focusedElement
    else
      # If no button is focused, we assume the first button in the form.
      return e.get(form, selector)

  ###**
  @function up.form.submitButtonSelector
  @internal
  ###
  submitButtonSelector = ->
    config.submitButtonSelectors.join(',')

  ###**
  Submits a form via AJAX and updates a page fragment with the response.

      up.submit('form.new-user', { target: '.main' })
  
  Instead of loading a new page, the form is submitted via AJAX.
  The response is parsed for a CSS selector and the matching elements will
  replace corresponding elements on the current page.

  The unobtrusive variant of this is the [`form[up-target]`](/form-up-target) selector.
  See the documentation for [`form[up-target]`](/form-up-target) for more
  information on how AJAX form submissions work in Unpoly.

  Emits the event [`up:form:submit`](/up:form:submit).

  @function up.submit
  @params-note
    All options from `up.render()` may be used.
  @param {Element|jQuery|string} form
    A reference or selector for the form to submit.
    If the argument points to an element that is not a form,
    Unpoly will search its ancestors for the closest form.
  @param {string} [options.url]
    The URL where to submit the form.
    Defaults to the form's `action` attribute, or to the current URL of the browser window.
  @param {string} [options.method='post']
    The HTTP method used for the form submission.
    Defaults to the form's `up-method`, `data-method` or `method` attribute, or to `'post'`
    if none of these attributes are given.
  @param {string} [options.target]
    The CSS selector to update when the form submission succeeds (server responds with status 200).
    Defaults to the form's `up-target` attribute.

    Inside the CSS selector you may refer to the form as `&` ([like in Sass](https://sass-lang.com/documentation/file.SASS_REFERENCE.html#parent-selector)).
  @param {string} [options.failTarget]
    The CSS selector to update when the form submission fails (server responds with non-200 status).
    Defaults to the form's `up-fail-target` attribute, or to an auto-generated
    selector that matches the form itself.

    Inside the CSS selector you may refer to the form as `&` ([like in Sass](https://sass-lang.com/documentation/file.SASS_REFERENCE.html#parent-selector)).
  @param {string} [options.fallback]
    The selector to update when the original target was not found in the page.
    Defaults to the form's `up-fallback` attribute.
  @param {boolean|string} [options.history=true]
    Successful form submissions will add a history entry and change the browser's
    location bar if the form either uses the `GET` method or the response redirected
    to another page (this requires the `unpoly-rails` gem).
    If you want to prevent history changes in any case, set this to `false`.
    If you pass a string, it is used as the URL for the browser history.
  @param {string} [options.transition='none']
    The transition to use when a successful form submission updates the `options.target` selector.
    Defaults to the form's `up-transition` attribute, or to `'none'`.
  @param {string} [options.failTransition='none']
    The transition to use when a failed form submission updates the `options.failTarget` selector.
    Defaults to the form's `up-fail-transition` attribute, or to `options.transition`, or to `'none'`.
  @param {number} [options.duration]
    The duration of the transition. See [`up.morph()`](/up.morph).
  @param {number} [options.delay]
    The delay before the transition starts. See [`up.morph()`](/up.morph).
  @param {string} [options.easing]
    The timing function that controls the transition's acceleration. [`up.morph()`](/up.morph).
  @param {Element|string} [options.reveal=true]
    Whether to reveal the target fragment after it was replaced.

    You can also pass a CSS selector for the element to reveal.
  @param {boolean|string} [options.failReveal=true]
    Whether to [reveal](/up.reveal) the target fragment when the server responds with an error.

    You can also pass a CSS selector for the element to reveal.
  @param {boolean} [options.restoreScroll]
    If set to `true`, this will attempt to [`restore scroll positions`](/up.restoreScroll)
    previously seen on the destination URL.
  @param {boolean} [options.cache]
    Whether to force the use of a cached response (`true`)
    or never use the cache (`false`)
    or make an educated guess (`undefined`).

    By default only responses to `GET` requests are cached
    for a few minutes.
  @param {Object} [options.headers={}]
    An object of additional header key/value pairs to send along
    with the request.
  @param {string} [options.layer='auto']
    The name of the layer that ought to be updated. Valid values are
    `'auto'`, `'page'`, `'modal'` and `'popup'`.

    If set to `'auto'` (default), Unpoly will try to find a match in the form's layer.
  @param {string} [options.failLayer='auto']
    The name of the layer that ought to be updated if the server sends a non-200 status code.
  @param {Object|FormData|string|Array|up.Params} [options.params]
    Extra form [parameters](/up.Params) that will be submitted in addition to
    the parameters from the form.
  @return {Promise}
    A promise for a successful form submission.
  @stable
  ###
  submit = up.mockable (form, options) ->
    return up.render(submitOptions(form, options))

  ###**
  Parses the `render()` options that would be used to
  [`submit`](/up.submit) the given form, but does not render.

  @param {Element|jQuery|string} form
    A reference or selector for the form to submit.
  @param {Object} [options]
    Additional options for the form submissions.

    Will override any attribute values set on the given form element.

    See `up.submit()` for detailled documentation of individual option properties.
  @function up.form.submitOptions
  @return {Object}
  @stable
  ###
  submitOptions = (form, options) ->
    options = u.options(options)
    form = up.fragment.get(form)
    form = e.closest(form, 'form')
    parser = new up.OptionsParser(options, form)

    # Parse params from form fields.
    params = up.Params.fromForm(form)

    if submitButton = submittingButton(form)
      # Submit buttons with a [name] attribute will add to the params.
      # Note that addField() will only add an entry if the given button has a [name] attribute.
      params.addField(submitButton)

      # Submit buttons may have [formmethod] and [formaction] attribute
      # that override [method] and [action] attribute from the <form> element.
      options.method ||= submitButton.getAttribute('formmethod')
      options.url ||= submitButton.getAttribute('formaction')

    params.addAll(options.params)
    options.params = params

    parser.string('url', attr: ['up-action', 'action'], default: up.fragment.source(form))
    parser.string('method', attr: ['up-method', 'data-method', 'method'], default: 'POST', normalize: u.normalizeMethod)
    if options.method == 'GET'
      # Only for GET forms, browsers discard all query params from the form's [action] URL.
      # The URLs search part will be replaced with the serialized form data.
      # See design/query-params-in-form-actions/cases.html for
      # a demo of vanilla browser behavior.
      options.url = up.Params.stripURL(options.url)

    parser.string('failTarget', default: up.fragment.toTarget(form))

    # The guardEvent will also be assigned an { renderOptions } property in up.render()
    options.guardEvent ||= up.event.build('up:form:submit', log: 'Submitting form')

    # Now that we have extracted everything form-specific into options, we can call
    # up.link.followOptions(). This will also parse the myriads of other options
    # that are possible on both <form> and <a> elements.
    u.assign(options, up.link.followOptions(form, options))

    return options

  ###**
  This event is [emitted](/up.emit) when a form is [submitted](/up.submit) through Unpoly.

  The event is emitted on the`<form>` element.

  @event up:form:submit
  @param {Element} event.target
    The `<form>` element that will be submitted.
  @param event.preventDefault()
    Event listeners may call this method to prevent the form from being submitted.
  @stable
  ###

  # MacOS does not focus buttons on click.
  # That means that submittingButton() cannot rely on document.activeElement.
  # See https://github.com/unpoly/unpoly/issues/103
  up.on 'up:click', submitButtonSelector, (event, button) ->
    button.focus()

  ###**
  Observes form fields and runs a callback when a value changes.

  This is useful for observing text fields while the user is typing.

  The unobtrusive variant of this is the [`[up-observe]`](/up-observe) attribute.

  \#\#\# Example

  The following would print to the console whenever an input field changes:

      up.observe('input.query', function(value) {
        console.log('Query is now %o', value)
      })

  Instead of a single form field, you can also pass multiple fields,
  a `<form>` or any container that contains form fields.
  The callback will be run if any of the given fields change:

      up.observe('form', function(value, name) {
        console.log('The value of %o is now %o', name, value)
      })

  You may also pass the `{ batch: true }` option to receive all
  changes since the last callback in a single object:

      up.observe('form', { batch: true }, function(diff) {
        console.log('Observed one or more changes: %o', diff)
      })

  @function up.observe
  @param {string|Element|Array<Element>|jQuery} elements
    The form fields that will be observed.

    You can pass one or more fields, a `<form>` or any container that contains form fields.
    The callback will be run if any of the given fields change.
  @param {boolean} [options.batch=false]
    If set to `true`, the `onChange` callback will receive multiple
    detected changes in a single diff object as its argument.
  @param {number} [options.delay=up.form.config.observeDelay]
    The number of miliseconds to wait before executing the callback
    after the input value changes. Use this to limit how often the callback
    will be invoked for a fast typist.
  @param {Function(value, name): string} onChange
    The callback to run when the field's value changes.

    If given as a function, it receives two arguments (`value`, `name`).
    `value` is a string with the new attribute value and `string` is the name
    of the form field that changed. If given as a string, it will be evaled as
    JavaScript code in a context where (`value`, `name`) are set.

    A long-running callback function may return a promise that settles when
    the callback completes. In this case the callback will not be called again while
    it is already running.
  @return {Function()}
    A destructor function that removes the observe watch when called.
  @stable
  ###
  observe = (elements, args...) ->
    elements = e.list(elements)
    fields = u.flatMap(elements, findFields)
    callback = u.extractCallback(args) ? observeCallbackFromElement(elements[0]) ? up.fail('up.observe: No change callback given')
    options = u.extractOptions(args)
    options.delay = options.delay ? e.numberAttr(elements[0], 'up-delay') ? config.observeDelay
    observer = new up.FieldObserver(fields, options, callback)
    observer.start()
    return -> observer.stop()

  observeCallbackFromElement = (element) ->
    if rawCallback = element.getAttribute('up-observe')
      new Function('value', 'name', rawCallback)

  ###**
  [Observes](/up.observe) a field or form and submits the form when a value changes.

  Both the form and the changed field will be assigned a CSS class [`form-up-active`](/form-up-active)
  while the autosubmitted form is processing.

  The unobtrusive variant of this is the [`up-autosubmit`](/form-up-autosubmit) attribute.

  @function up.autosubmit
  @param {string|Element|jQuery} target
    The field or form to observe.
  @param {Object} [options]
    See options for [`up.observe()`](/up.observe)
  @return {Function()}
    A destructor function that removes the observe watch when called.
  @stable
  ###
  autosubmit = (target, options) ->
    observe(target, options, -> submit(target))

  findValidateTarget = (element, options) ->
    container = getContainer(element)

    if u.isElementish(options.target)
      return up.fragment.toTarget(options.target)
    else if givenTarget = options.target || element.getAttribute('up-validate') || container.getAttribute('up-validate')
      return givenTarget
    else if e.matches(element, 'form')
      # If element is the form, we cannot find a better validate target than this.
      return up.fragment.toTarget(element)
    else
      return findValidateTargetFromConfig(element, options) || up.fail('Could not find validation target for %o (tried defaults %o)', element, config.validateTargets)

  findValidateTargetFromConfig = (element, options) ->
    # for the first selector that has a match in the field's layer.
    layer = up.layer.get(element)
    return u.findResult config.validateTargets, (defaultTarget) ->
      if up.fragment.get(defaultTarget, u.merge(options, { layer }))
        # We want to return the selector, *not* the element. If we returned the element
        # and derive a selector from that, any :has() expression would be lost.
        return defaultTarget

  ###**
  Performs a server-side validation of a form field.

  `up.validate()` submits the given field's form with an additional `X-Up-Validate`
  HTTP header. Upon seeing this header, the server is expected to validate (but not save)
  the form submission and render a new copy of the form with validation errors.

  The unobtrusive variant of this is the [`input[up-validate]`](/input-up-validate) selector.
  See the documentation for [`input[up-validate]`](/input-up-validate) for more information
  on how server-side validation works in Unpoly.

  \#\#\# Example

      up.validate('input[name=email]', { target: '.email-errors' })

  @function up.validate
  @param {string|Element|jQuery} field
    The form field to validate.
  @param {string|Element|jQuery} [options.target]
    The element that will be [updated](/up.render) with the validation results.
  @return {Promise}
    A promise that fulfills when the server-side
    validation is received and the form was updated.
  @stable
  ###
  validate = (field, options) ->
    # If passed a selector, up.fragment.get() will prefer a match on the current layer.
    field = up.fragment.get(field)

    options = u.options(options)
    options.navigate = false
    options.origin = field
    options.history = false
    options.target = findValidateTarget(field, options)
    options.focus = 'keep'

    # The protocol doesn't define whether the validation results in a status code.
    # Hence we use the same options for both success and failure.
    options.fail = false

    # Make sure the X-Up-Validate header is present, so the server-side
    # knows that it should not persist the form submission
    options.headers ||= {}
    options.headers[up.protocol.headerize('validate')] = field.getAttribute('name') || ':unknown'

    # The guardEvent will also be assigned a { renderOptions } attribute in up.render()
    options.guardEvent = up.event.build('up:form:validate', log: 'Validating form')

    return submit(field, options)

  switcherValues = (field) ->
    value = undefined
    meta = undefined

    if e.matches(field, 'input[type=checkbox]')
      if field.checked
        value = field.value
        meta = ':checked'
      else
        meta = ':unchecked'
    else if e.matches(field, 'input[type=radio]')
      form = getContainer(field)
      groupName = field.getAttribute('name')
      checkedButton = form.querySelector("input[type=radio]#{e.attributeSelector('name', groupName)}:checked")
      if checkedButton
        meta = ':checked'
        value = checkedButton.value
      else
        meta = ':unchecked'
    else
      value = field.value

    values = []
    if u.isPresent(value)
      values.push(value)
      values.push(':present')
    else
      values.push(':blank')
    if u.isPresent(meta)
      values.push(meta)
    values

  ###**
  Shows or hides a target selector depending on the value.

  See [`input[up-switch]`](/input-up-switch) for more documentation and examples.

  This function does not currently have a very useful API outside
  of our use for `up-switch`'s UJS behavior, that's why it's currently
  still marked `@internal`.

  @function up.form.switchTargets
  @param {Element} switcher
  @param {string} [options.target]
    The target selectors to switch.
    Defaults to an `[up-switch]` attribute on the given field.
  @internal
  ###
  switchTargets = (switcher, options = {}) ->
    targetSelector = options.target ? switcher.getAttribute('up-switch')
    form = getContainer(switcher)
    targetSelector or up.fail("No switch target given for %o", switcher)
    fieldValues = switcherValues(switcher)

    u.each e.all(form, targetSelector), (target) ->
      switchTarget(target, fieldValues)

  ###**
  @internal
  ###
  switchTarget = up.mockable (target, fieldValues) ->
    fieldValues ||= switcherValues(findSwitcherForTarget(target))

    if hideValues = target.getAttribute('up-hide-for')
      hideValues = u.splitValues(hideValues)
      show = u.intersect(fieldValues, hideValues).length == 0
    else
      if showValues = target.getAttribute('up-show-for')
        showValues = u.splitValues(showValues)
      else
        # If the target has neither up-show-for or up-hide-for attributes,
        # assume the user wants the target to be visible whenever anything
        # is checked or entered.
        showValues = [':present', ':checked']
      show = u.intersect(fieldValues, showValues).length > 0

    e.toggle(target, show)
    target.classList.add('up-switched')

  ###**
  @internal
  ###
  findSwitcherForTarget = (target) ->
    form = getContainer(target)
    switchers = e.all(form, '[up-switch]')
    switcher = u.find switchers, (switcher) ->
      targetSelector = switcher.getAttribute('up-switch')
      e.matches(target, targetSelector)
    return switcher or up.fail('Could not find [up-switch] field for %o', target)

  getContainer = (element) ->
    element.form || # Element#form will also work if the element is outside the form with an [form=form-id] attribute
      e.closest(element, "form, #{up.layer.anySelector()}")

  focusedField = ->
    if (element = document.activeElement) && e.matches(element, fieldSelector())
      return element

  ###**
  Forms with an `up-target` attribute are [submitted via AJAX](/up.submit)
  instead of triggering a full page reload.

      <form method="post" action="/users" up-target=".main">
        ...
      </form>

  The server response is searched for the selector given in `up-target`.
  The selector content is then [replaced](/up.replace) in the current page.

  The programmatic variant of this is the [`up.submit()`](/up.submit) function.

  \#\#\# Failed submission

  When the server was unable to save the form due to invalid params,
  it will usually re-render an updated copy of the form with
  validation messages.

  For Unpoly to be able to detect a failed form submission,
  the form must be re-rendered with a non-200 HTTP status code.
  We recommend to use either 400 (bad request) or
  422 (unprocessable entity).

  In Ruby on Rails, you can pass a
  [`:status` option to `render`](http://guides.rubyonrails.org/layouts_and_rendering.html#the-status-option)
  for this:

      class UsersController < ApplicationController

        def create
          user_params = params[:user].permit(:email, :password)
          @user = User.new(user_params)
          if @user.save?
            sign_in @user
          else
            render 'form', status: :bad_request
          end
        end

      end

  Note that you can also use
  [`input[up-validate]`](/input-up-validate) to perform server-side
  validations while the user is completing fields.

  \#\#\# Redirects

  Unpoly requires an additional response header to detect redirects,
  which are otherwise undetectable for an AJAX client.

  After the form's action performs a redirect, the next response should echo
  the new request's URL as a response header `X-Up-Location`.

  If you are using Unpoly via the `unpoly-rails` gem, these headers
  are set automatically for every request.

  \#\#\# Giving feedback while the form is processing

  The `<form>` element will be assigned a CSS class [`up-active`](/form.up-active) while
  the submission is loading.

  You can also [implement a spinner](/up.network/#spinners)
  by [listening](/up.on) to the [`up:request:late`](/up:request:late)
  and [`up:request:recover`](/up:request:recover) events.

  @selector form[up-target]
  @param {string} up-target
    The CSS selector to [replace](/up.replace) if the form submission is successful (200 status code).

    Inside the CSS selector you may refer to this form as `&` ([like in Sass](https://sass-lang.com/documentation/file.SASS_REFERENCE.html#parent-selector)).
  @param {string} [up-fail-target]
    The CSS selector to [replace](/up.replace) if the form submission is not successful (non-200 status code).

    Inside the CSS selector you may refer to this form as `&` ([like in Sass](https://sass-lang.com/documentation/file.SASS_REFERENCE.html#parent-selector)).

    If omitted, Unpoly will replace the `<form>` tag itself, assuming that the server has echoed the form with validation errors.
  @param [up-fallback]
    The selector to replace if the server responds with an error.
  @param {string} [up-transition]
    The animation to use when the form is replaced after a successful submission.
  @param {string} [up-fail-transition]
    The animation to use when the form is replaced after a failed submission.
  @param [up-history]
    Whether to push a browser history entry after a successful form submission.

    By default the form's target URL is used. If the form redirects to another URL,
    the redirect target will be used.

    Set this to `'false'` to prevent the URL bar from being updated.
    Set this to a URL string to update the history with the given URL.
  @param {string} [up-method]
    The HTTP method to be used to submit the form (`get`, `post`, `put`, `delete`, `patch`).
    Alternately you can use an attribute `data-method`
    ([Rails UJS](https://github.com/rails/jquery-ujs/wiki/Unobtrusive-scripting-support-for-jQuery))
    or `method` (vanilla HTML) for the same purpose.
  @param {string} [up-layer='auto']
    The name of the layer that ought to be updated. Valid values are
    `'auto'`, `'page'`, `'modal'` and `'popup'`.

    If set to `'auto'` (default), Unpoly will try to find a match in the form's layer.
    If no match was found in that layer,
    Unpoly will search in other layers, starting from the topmost layer.
  @param {string} [up-fail-layer='auto']
    The name of the layer that ought to be updated if the server sends a
    non-200 status code.
  @param {string} [up-reveal='true']
    Whether to reveal the target element after it was replaced.

    You can also pass a CSS selector for the element to reveal.
    Inside the CSS selector you may refer to the form as `&` ([like in Sass](https://sass-lang.com/documentation/file.SASS_REFERENCE.html#parent-selector)).
  @param {string} [up-fail-reveal='true']
    Whether to reveal the target element when the server responds with an error.

    You can also pass a CSS selector for the element to reveal. You may use this, for example,
    to reveal the first validation error message:

        <form up-target=".content" up-fail-reveal=".error">
          ...
        </form>

    Inside the CSS selector you may refer to the form as `&` ([like in Sass](https://sass-lang.com/documentation/file.SASS_REFERENCE.html#parent-selector)).
  @param {string} [up-restore-scroll='false']
    Whether to restore previously known scroll position of all viewports
    within the target selector.
  @param {string} [up-cache]
    Whether to force the use of a cached response (`true`)
    or never use the cache (`false`)
    or make an educated guess (`undefined`).

    By default only responses to `GET` requests are cached for a few minutes.
  @stable
  ###
  up.on 'submit', fullSubmitSelector, (event, form) ->
    # Users may configure up.form.config.submitSelectors.push('form')
    # and then opt out individual forms with [up-submit=false].
    if e.matches(form, '[up-submit=false]')
      return

    abortScheduledValidate?()
    up.event.halt(event)
    up.log.muteRejection submit(form)

  ###**
  TODO: Docs

  @selector form[up-submit]
  ###

  ###**
  When a form field with this attribute is changed, the form is validated on the server
  and is updated with validation messages.

  To validate the form, Unpoly will submit the form with an additional `X-Up-Validate` HTTP header.
  When seeing this header, the server is expected to validate (but not save)
  the form submission and render a new copy of the form with validation errors.

  The programmatic variant of this is the [`up.validate()`](/up.validate) function.

  \#\#\# Example

  Let's look at a standard registration form that asks for an e-mail and password:

      <form action="/users">

        <label>
          E-mail: <input type="text" name="email" />
        </label>

        <label>
          Password: <input type="password" name="password" />
        </label>

        <button type="submit">Register</button>

      </form>

  When the user changes the `email` field, we want to validate that
  the e-mail address is valid and still available. Also we want to
  change the `password` field for the minimum required password length.
  We can do this by giving both fields an `up-validate` attribute:

      <form action="/users">

        <label>
          E-mail: <input type="text" name="email" up-validate />
        </label>

        <label>
          Password: <input type="password" name="password" up-validate />
        </label>

        <button type="submit">Register</button>

      </form>

  Whenever a field with `up-validate` changes, the form is POSTed to
  `/users` with an additional `X-Up-Validate` HTTP header.
  When seeing this header, the server is expected to validate (but not save)
  the form submission and render a new copy of the form with validation errors.

  In Ruby on Rails the processing action should behave like this:

      class UsersController < ApplicationController

        # This action handles POST /users
        def create
          user_params = params[:user].permit(:email, :password)
          @user = User.new(user_params)
          if request.headers['X-Up-Validate']
            @user.valid?  # run validations, but don't save to the database
            render 'form' # render form with error messages
          elsif @user.save?
            sign_in @user
          else
            render 'form', status: :bad_request
          end
        end

      end

  Note that if you're using the `unpoly-rails` gem you can simply say `up.validate?`
  instead of manually checking for `request.headers['X-Up-Validate']`.

  The server now renders an updated copy of the form with eventual validation errors:

      <form action="/users">

        <label class="has-error">
          E-mail: <input type="text" name="email" value="foo@bar.com" />
          Has already been taken!
        </label>

        <button type="submit">Register</button>

      </form>

  The `<label>` around the e-mail field is now updated to have the `has-error`
  class and display the validation message.

  \#\#\# How validation results are displayed

  Although the server will usually respond to a validation with a complete,
  fresh copy of the form, Unpoly will by default not update the entire form.
  This is done in order to preserve volatile state such as the scroll position
  of `<textarea>` elements.

  By default Unpoly looks for a `<fieldset>`, `<label>` or `<form>`
  around the validating input field, or any element with an
  `up-fieldset` attribute.
  With the Bootstrap bindings, Unpoly will also look
  for a container with the `form-group` class.

  You can change this default behavior by setting `up.form.config.validateTargets`:

      // Always update the entire form containing the current field ("&")
      up.form.config.validateTargets = ['form &']

  You can also individually override what to update by setting the `up-validate`
  attribute to a CSS selector:

      <input type="text" name="email" up-validate=".email-errors">
      <span class="email-errors"></span>

  \#\#\# Updating dependent fields

  The `[up-validate]` behavior is also a great way to partially update a form
  when one fields depends on the value of another field.

  Let's say you have a form with one `<select>` to pick a department (sales, engineering, ...)
  and another `<select>` to pick an employeee from the selected department:

      <form action="/contracts">
        <select name="department">...</select> <!-- options for all departments -->
        <select name="employeed">...</select> <!-- options for employees of selected department -->
      </form>

  The list of employees needs to be updated as the appartment changes:

      <form action="/contracts">
        <select name="department" up-validate="[name=employee]">...</select>
        <select name="employee">...</select>
      </form>

  In order to update the `department` field in addition to the `employee` field, you could say
  `up-validate="&, [name=employee]"`, or simply `up-validate="form"` to update the entire form.

  @selector input[up-validate]
  @param {string} up-validate
    The CSS selector to update with the server response.

    This defaults to a fieldset or form group around the validating field.
  @stable
  ###

  ###**
  Performs [server-side validation](/input-up-validate) when any fieldset within this form changes.

  You can configure what Unpoly considers a fieldset by adding CSS selectors to the
  `up.form.config.validateTargets` array.

  @selector form[up-validate]
  @param {string} up-validate
    The CSS selector to update with the server response.

    This defaults to a fieldset or form group around the changing field.
  @stable
  ###
  up.on 'change', '[up-validate]', (event) ->
    # Even though [up-validate] may be used on either an entire form or an individual input,
    # the change event will trigger on a given field.
    field = findFields(event.target)[0]

    # There is an edge case where the user is changing an input with [up-validate],
    # but blurs the input by directly clicking the submit button. In this case the
    # following events will be emitted:
    #
    # - change on the input
    # - focus on the button
    # - submit on the form
    #
    # In this case we do not want to send a validate request to the server, but
    # simply submit the form. Because this event handler does not know if a submit
    # event is about to fire, we delay the validation to the next microtask.
    # In case we receive a submit event after this, we can cancel the validation.
    abortScheduledValidate = u.abortableMicrotask ->
      up.log.muteRejection validate(field)

  ###**
  Show or hide elements when a `<select>` or `<input>` has a given value.

  \#\#\# Example: Select options

  The controlling form field gets an `up-switch` attribute with a selector for the elements to show or hide:

      <select name="advancedness" up-switch=".target">
        <option value="basic">Basic parts</option>
        <option value="advanced">Advanced parts</option>
        <option value="very-advanced">Very advanced parts</option>
      </select>

  The target elements can use [`[up-show-for]`](/up-show-for) and [`[up-hide-for]`](/up-hide-for)
  attributes to indicate for which values they should be shown or hidden:

      <div class="target" up-show-for="basic">
        only shown for advancedness = basic
      </div>

      <div class="target" up-hide-for="basic">
        hidden for advancedness = basic
      </div>

      <div class="target" up-show-for="advanced very-advanced">
        shown for advancedness = advanced or very-advanced
      </div>

  \#\#\# Example: Text field

  The controlling `<input>` gets an `up-switch` attribute with a selector for the elements to show or hide:

      <input type="text" name="user" up-switch=".target">

      <div class="target" up-show-for="alice">
        only shown for user alice
      </div>

  You can also use the pseudo-values `:blank` to match an empty input value,
  or `:present` to match a non-empty input value:

      <input type="text" name="user" up-switch=".target">

      <div class="target" up-show-for=":blank">
        please enter a username
      </div>

  \#\#\# Example: Checkbox

  For checkboxes you can match against the pseudo-values `:checked` or `:unchecked`:

      <input type="checkbox" name="flag" up-switch=".target">

      <div class="target" up-show-for=":checked">
        only shown when checkbox is checked
      </div>

      <div class="target" up-show-for=":cunhecked">
        only shown when checkbox is unchecked
      </div>

  Of course you can also match against the `value` property of the checkbox element:

      <input type="checkbox" name="flag" value="active" up-switch=".target">

      <div class="target" up-show-for="active">
        only shown when checkbox is checked
      </div>

  @selector input[up-switch]
  @param {string} up-switch
    A CSS selector for elements whose visibility depends on this field's value.
  @stable
  ###

  ###**
  Only shows this element if an input field with [`[up-switch]`](/input-up-switch) has one of the given values.

  See [`input[up-switch]`](/input-up-switch) for more documentation and examples.

  @selector [up-show-for]
  @param {string} [up-show-for]
    A space-separated list of input values for which this element should be shown.
  @stable
  ###

  ###**
  Hides this element if an input field with [`[up-switch]`](/input-up-switch) has one of the given values.

  See [`input[up-switch]`](/input-up-switch) for more documentation and examples.

  @selector [up-hide-for]
  @param {string} [up-hide-for]
    A space-separated list of input values for which this element should be hidden.
  @stable
  ###
  up.compiler '[up-switch]', (switcher) ->
    switchTargets(switcher)

  up.on 'change', '[up-switch]', (event, switcher) ->
    switchTargets(switcher)

  up.compiler '[up-show-for]:not(.up-switched), [up-hide-for]:not(.up-switched)', (element) ->
    switchTarget(element)

  ###**
  Observes this field and runs a callback when a value changes.

  This is useful for observing text fields while the user is typing.
  If you want to submit the form after a change see [`input[up-autosubmit]`](/input-up-autosubmit).

  The programmatic variant of this is the [`up.observe()`](/up.observe) function.

  \#\#\# Example

  The following would run a global `showSuggestions(value)` function
  whenever the `<input>` changes:

      <input name="query" up-observe="showSuggestions(value)">

  \#\#\# Callback context

  The script given to `[up-observe]` runs with the following context:

  | Name     | Type      | Description                           |
  | -------- | --------- | ------------------------------------- |
  | `value`  | `string`  | The current value of the field        |
  | `this`   | `Element` | The form field                        |
  | `$field` | `jQuery`  | The form field as a jQuery collection |

  \#\#\# Observing radio buttons

  Multiple radio buttons with the same `[name]` (a radio button group)
  produce a single value for the form.

  To observe radio buttons group, use the `[up-observe]` attribute on an
  element that contains all radio button elements with a given name:

      <div up-observe="formatSelected(value)">
        <input type="radio" name="format" value="html"> HTML format
        <input type="radio" name="format" value="pdf"> PDF format
        <input type="radio" name="format" value="txt"> Text format
      </div>

  @selector input[up-observe]
  @param {string} up-observe
    The code to run when the field's value changes.
  @param {string} up-delay
    The number of miliseconds to wait after a change before the code is run.
  @stable
  ###

  ###**
  Observes this form and runs a callback when any field changes.

  This is useful for observing text fields while the user is typing.
  If you want to submit the form after a change see [`input[up-autosubmit]`](/input-up-autosubmit).

  The programmatic variant of this is the [`up.observe()`](/up.observe) function.

  \#\#\# Example

  The would call a function `somethingChanged(value)`
  when any `<input>` within the `<form>` changes:

      <form up-observe="somethingChanged(value)">
        <input name="foo">
        <input name="bar">
      </form>

  \#\#\# Callback context

  The script given to `[up-observe]` runs with the following context:

  | Name     | Type      | Description                           |
  | -------- | --------- | ------------------------------------- |
  | `value`  | `string`  | The current value of the field        |
  | `this`   | `Element` | The form field                        |
  | `$field` | `jQuery`  | The form field as a jQuery collection |

  @selector form[up-observe]
  @param {string} up-observe
    The code to run when any field's value changes.
  @param {string} up-delay
    The number of miliseconds to wait after a change before the code is run.
  @stable
  ###
  up.compiler '[up-observe]', (formOrField) -> observe(formOrField)

  ###**
  Submits this field's form when this field changes its values.

  Both the form and the changed field will be assigned a CSS class [`up-active`](/form-up-active)
  while the autosubmitted form is loading.

  The programmatic variant of this is the [`up.autosubmit()`](/up.autosubmit) function.

  \#\#\# Example

  The following would automatically submit the form when the query is changed:

      <form method="GET" action="/search">
        <input type="search" name="query" up-autosubmit>
        <input type="checkbox" name="archive"> Include archive
      </form>

  \#\#\# Auto-submitting radio buttons

  Multiple radio buttons with the same `[name]` (a radio button group)
  produce a single value for the form.

  To auto-submit radio buttons group, use the `[up-submit]` attribute on an
  element that contains all radio button elements with a given name:

      <div up-autosubmit>
        <input type="radio" name="format" value="html"> HTML format
        <input type="radio" name="format" value="pdf"> PDF format
        <input type="radio" name="format" value="txt"> Text format
      </div>

  @selector input[up-autosubmit]
  @param {string} up-delay
    The number of miliseconds to wait after a change before the form is submitted.
  @stable
  ###

  ###**
  Submits the form when *any* field changes.

  Both the form and the field will be assigned a CSS class [`up-active`](/form-up-active)
  while the autosubmitted form is loading.

  The programmatic variant of this is the [`up.autosubmit()`](/up.autosubmit) function.

  \#\#\# Example

  This will submit the form when either query or checkbox was changed:

      <form method="GET" action="/search" up-autosubmit>
        <input type="search" name="query">
        <input type="checkbox" name="archive"> Include archive
      </form>

  @selector form[up-autosubmit]
  @param {string} up-delay
    The number of miliseconds to wait after a change before the form is submitted.
  @stable
  ###
  up.compiler '[up-autosubmit]', (formOrField) -> autosubmit(formOrField)

  up.on 'up:framework:reset', reset

  config: config
  submit: submit
  submitOptions: submitOptions
  observe: observe
  validate: validate
  autosubmit: autosubmit
  fieldSelector: fieldSelector
  fields: findFields
  focusedField: focusedField
  switchTarget: switchTarget

up.submit = up.form.submit
up.observe = up.form.observe
up.autosubmit = up.form.autosubmit
up.validate = up.form.validate
