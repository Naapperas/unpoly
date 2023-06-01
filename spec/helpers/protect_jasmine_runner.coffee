u = up.util
e = up.element
$ = jQuery

window.safeHistory = new class
  constructor: ->
    @logEnabled = false
    @cursor = -1 # we don't know the initial state
    @stateIndexes = []
    @nextIndex = 1000

  back: ->
    @log("safeHistory: back(), cursor before is %o, path before is %o", @cursor, location.pathname)
    if @cursor > 0
      # This will trigger popstate, which we will handle and update @cursor
      oldBack.call(history)
    else
      up.fail('safeHistory: Tried to go too far back in history (prevented)')

  forward: ->
    @log("safeHistory: forward()")
    if @cursor < @stateIndexes.length - 1
      # This will trigger popstate, which we will handle and update @cursor
      oldForward.call(history)
    else
      up.fail('safeHistory: Tried to go too far forward in history (prevented)')

  pushState: (state, title, url) ->
    state ||= { state }
    state._index = @nextIndex++

    @log("safeHistory: pushState(%o, %o, %o)", state, title, url)
    oldPushState.call(history, state, title, url)

    if url && u.normalizeURL(url) != u.normalizeURL(location.href)
      up.fail('safeHistory: Browser did now allow history.pushState() to URL %s (Chrome throttling history changes?)', url)

    @stateIndexes.splice(@cursor + 1, @stateIndexes.length, state._index)
    @cursor++
    @log("safeHistory: @stateIndexes are now %o, cursor is %o, path is %o", u.copy(@stateIndexes), @cursor, location.pathname)

  replaceState: (state, title, url) ->
    state ||= { state }
    state._index = @nextIndex++

    @log("safeHistory: replaceState(%o, %o, %o)", state, title, url)
    oldReplaceState.call(history, state, title, url)

    if url && u.normalizeURL(url) != u.normalizeURL(location.href)
      up.fail('safeHistory: Browser did now allow history.replaceState() to URL %s (Chrome throttling history changes?)', url)

    # In case an example uses replaceState to set a known initial URL
    # we can use this to know our initial state.
    @cursor = 0 if @cursor == -1
    @stateIndexes[@cursor] = state._index
    @log("safeHistory: @stateIndexes are now %o, cursor is %o, path is %o", u.copy(@stateIndexes), @cursor, location.pathname)

  onPopState: (event) ->
    state = event.state
    @log("safeHistory: Got event %o with state %o", event, state)

    return unless state

    @log("safeHistory: restored(%o)", state._index)
    @cursor = @stateIndexes.indexOf(state._index)

    if @cursor == -1
      up.fail('safeHistory: Could not find position of state %o', state)

    @log("safeHistory: @stateIndexes are now %o, cursor is %o, path is %o", u.copy(@stateIndexes), @cursor, location.pathname)

  log: (args...) ->
    if @logEnabled
      console.debug(args...)

  afterEach: ->
    @cursor = 0
    @stateIndexes = [@stateIndexes[@cursor]]

  reset: ->
    @log("safeHistory: reset()")
    @cursor = 0
    @stateIndexes = [0]

oldPushState = history.pushState
oldReplaceState = history.replaceState
oldBack = history.back
oldForward = history.forward

history.pushState = (args...) -> safeHistory.pushState(args...)
history.replaceState = (args...) -> safeHistory.replaceState(args...)
history.back = (args...) -> safeHistory.back(args...)
history.forward = (args...) -> safeHistory.forward(args...)

window.addEventListener('popstate', (event) -> safeHistory.onPopState(event))

afterEach ->
  safeHistory.afterEach()

willScrollWithinPage = (link) ->
  verbatimHREF = link.getAttribute('href')

  linkURL = u.normalizeURL(verbatimHREF, hash: false)
  currentURL = u.normalizeURL(up.history.location, hash: false)
  return linkURL == currentURL

# Make specs fail if a link was followed without Unpoly.
# This would otherwise navigate away from the spec runner.
beforeEach ->
  window.defaultFollowedLinks = []

  up.on 'click', 'a[href]', (event) ->
    link = event.target

    browserWouldNavigate = !event.defaultPrevented &&
      !link.getAttribute('href').match(/^javascript:/) &&
      !willScrollWithinPage(link)

    if browserWouldNavigate
      console.debug('Preventing browser navigation to preserve test runner (caused by click on link %o)', link)
      window.defaultFollowedLinks.push(link)
      event.preventDefault() # prevent browsers from leaving the test runner

  jasmine.addMatchers
    toHaveBeenDefaultFollowed: (util, customEqualityTesters) ->
      compare: (link) ->
        link = e.get(link)
        used = !!u.remove(window.defaultFollowedLinks, link)
        pass: used

afterEach ->
  if links = u.presence(window.defaultFollowedLinks)
    up.fail('Unhandled default click behavior for links %o', links)

# Make specs fail if a form was followed without Unpoly.
# This would otherwise navigate away from the spec runner.
beforeEach ->
  window.defaultSubmittedForms = []

  up.on 'submit', 'form', (event) ->
    form = event.target

    browserWouldNavigate = !u.contains(form.action, '#') && !event.defaultPrevented

    if browserWouldNavigate
      console.debug('Preventing browser navigation to preserve test runner (caused by submission of form %o)', form)
      window.defaultSubmittedForms.push(form)
      event.preventDefault()

  jasmine.addMatchers
    toHaveBeenDefaultSubmitted: (util, customEqualityTesters) ->
      compare: (form) ->
        form = e.get(form)
        used = !!u.remove(window.defaultSubmittedForms, form)
        pass: used

afterEach ->
  if forms = u.presence(window.defaultSubmittedForms)
    up.fail('Unhandled default click behavior for forms %o', forms)

# Add a .default-fallback container to every layer, so we never
# end up swapping the <body> element.
appendDefaultFallback = (parent) ->
  e.affix(parent, 'default-fallback')

beforeEach ->
  up.fragment.config.resetTargets = []
  u.remove(up.layer.config.any.mainTargets, ':layer')
  up.layer.config.any.mainTargets.push('default-fallback')
  up.layer.config.overlay.mainTargets.push(':layer') # this would usually be in config.any, but have removed it
  up.history.config.restoreTargets = ['default-fallback']
  appendDefaultFallback(document.body)

afterEach ->
  for element in document.querySelectorAll('default-fallback')
    up.destroy(element, log: false)

# Restore the original <body> (containing the Jasmine runner) in case a spec replaces the <body>
originalBody = null

beforeAll ->
  originalBody = document.body

afterEach ->
  if originalBody != document.body
    console.debug("Restoring <body> that was swapped by a spec")
    # Restore the Jasmine test runner that we just nuked
    document.body.replaceWith(originalBody)
    # The body get an .up-destroying class when it was swapped. We must remove it
    # or up.fragment will ignore everything within the body from now on.
    document.body.classList.remove('up-destroying')
    document.body.removeAttribute('aria-hidden')
