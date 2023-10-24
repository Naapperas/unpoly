u = up.util

RESET_MESSAGE = 'Resetting framework for next test'

logResetting = ->
  console.debug("%c#{RESET_MESSAGE}", 'color: #2244aa')

resetLocation = ->
  # Webkit ignores replaceState() calls after 100 calls / 30 sec.
  # Hence we only call it when the history was actually changed.
  unless up.util.matchURLs(location.href, jasmine.locationBeforeSuite)
    history.replaceState?({ fromResetPathHelper: true }, '', jasmine.locationBeforeSuite)

resetTitle = ->
  unless document.title == jasmine.titleBeforeSuite
    document.title = jasmine.titleBeforeSuite

resetHeadMetas = ->
  currentMetas = findHeadMetas()

  unless u.isEqual(currentMetas, jasmine.headMetasBeforeSuite)
    for meta in currentMetas
      meta.remove()

    for savedMeta in jasmine.headMetasBeforeSuite
      document.head.append(savedMeta)

findHeadMetas = ->
  document.head.querySelectorAll('meta, link:not([rel=stylesheet])')

beforeAll ->
  jasmine.titleBeforeSuite = document.title

  jasmine.locationBeforeSuite = location.href

  jasmine.headMetasBeforeSuite = findHeadMetas()

  # Ignore <meta> and <link> tags from the Jasmine runner
  for meta in jasmine.headMetasBeforeSuite
    meta.setAttribute('up-meta', 'false')

beforeEach ->
  # Store original URL and title so specs may use it
  jasmine.locationBeforeExample = location.href

afterEach ->
  # Wait 1 more frame for async errors to (correctly) fail the test.
  await wait()

  # Ignore errors while the framework is being reset.
  await jasmine.spyOnGlobalErrorsAsync (_globalErrorSpy) ->
    logResetting()

    # If the spec has installed the Jasmine clock, uninstall it so
    # the timeout below will actually happen.
    jasmine.clock().uninstall()

    # Abort all requests so any cancel handlers can run and do async things.
    up.network.abort(reason: RESET_MESSAGE)

    # Most pending promises will wait for an animation to finish.
    up.motion.finish()

    up.browser.popCookie(up.protocol.config.methodCookie)

    # Wait one more frame so pending callbacks have a chance to run.
    # Pending callbacks might change the URL or cause errors that bleed into
    # the next example.
    await wait()

    # Reset browser location and meta/link elements to those from before the suite.
    # Some resetting modules (like up.history) need to be called after the URL was been reset.
    resetLocation()
    resetTitle()
    resetHeadMetas()

    up.framework.reset()

    # Give async reset behavior another frame to play out,
    # then start the next example.
    await wait()

    # Make some final checks that we have reset successfully
    overlays = document.querySelectorAll('up-modal, up-popup, up-cover, up-drawer')
    if overlays.length > 0
      throw new Error("Overlays survived reset!")

    if document.querySelector('up-progress-bar')
      throw new Error('Progress bar survived reset!')

#    # Remove styles from a crashed up.BodyShifter
#    document.body.removeAttribute('style')

    # Scroll to the top
    document.scrollingElement.scrollTop = 0

    up.puts('specs', 'Framework was reset')
