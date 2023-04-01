u = up.util
e = up.element
$ = jQuery

describe 'up.link', ->

  u = up.util

  describe 'JavaScript functions', ->

    describe 'up.follow', ->

      it 'loads the given link via AJAX and replaces the response in the given target', asyncSpec (next) ->
        fixture('.before', text: 'old-before')
        fixture('.middle', text: 'old-middle')
        fixture('.after', text: 'old-after')
        link = fixture('a[href="/path"][up-target=".middle"]')

        up.follow(link)

        next ->
          jasmine.respondWith """
            <div class="before">new-before</div>
            <div class="middle">new-middle</div>
            <div class="after">new-after</div>
            """

        next ->
          expect('.before').toHaveText('old-before')
          expect('.middle').toHaveText('new-middle')
          expect('.after').toHaveText('old-after')

      it 'uses the method from a data-method attribute', asyncSpec (next) ->
        link = fixture('a[href="/path"][data-method="PUT"]')
        up.follow(link)

        next ->
          request = jasmine.lastRequest()
          expect(request).toHaveRequestMethod('PUT')

      it 'allows to refer to the link itself as ":origin" in the CSS selector', asyncSpec (next) ->
        container = fixture('div')
        link1 = e.createFromHTML('<a id="first" href="/path" up-target=":origin">first-link</a>')
        container.append(link1)

        link2 = e.createFromHTML('<a id="second" href="/path" up-target=":origin">second-link</a>')
        container.append(link2)
        up.follow(link2)

        next -> jasmine.respondWith '<div id="second">second-div</div>'
        next -> expect(container).toHaveText('first-linksecond-div')

      it 'returns a promise with an up.RenderResult that contains information about the updated fragments and layer', asyncSpec (next) ->
        fixture('.one', text: 'old one')
        fixture('.two', text: 'old two')
        fixture('.three', text: 'old three')

        link = fixture('a[up-target=".one, .three"][href="/path"]')

        promise = up.follow(link)

        next =>
          @respondWith """
            <div class="one">new one</div>
            <div class="two">new two</div>
            <div class="three">new three</div>
          """

        next =>
          next.await promiseState(promise)

        next (result) =>
          expect(result.state).toBe('fulfilled')
          expect(result.value.fragments).toEqual([document.querySelector('.one'), document.querySelector('.three')])
          expect(result.value.layer).toBe(up.layer.root)

      it 'still renders if the link was removed while the request was in flight (e.g. when the user clicked a link in a custom overlay that closes on mouseout)', asyncSpec (next) ->
        fixture('.target', text: 'old text')

        link = fixture('a[up-target=".target"][href="/foo"]')

        promise = up.follow(link)

        next ->
          expect(jasmine.Ajax.requests.count()).toEqual(1)

          link.remove()

        next ->
          jasmine.respondWithSelector('.target', text: 'new text')

        next ->
          expect('.target').toHaveText('new text')
          next.await promiseState(promise)

        next (result) ->
          expect(result.state).toBe('fulfilled')
          expect(window).not.toHaveUnhandledRejections()

#      it 'does not change focus in a programmatic call', asyncSpec (next) ->
#        input = fixture('input[type=text]')
#        target = fixture('.target')
#        link = fixture('a[href="/path"][up-target=".target"]')
#
#        input.focus()
#        expect(input).toBeFocused()
#        up.follow(link)
#
#        next ->
#          # Assert that focus did not change
#          expect(input).toBeFocused()

      describe 'events', ->

        it 'emits a preventable up:link:follow event', asyncSpec (next) ->
          link = fixture('a[href="/destination"][up-target=".response"]')

          listener = jasmine.createSpy('follow listener').and.callFake (event) ->
            event.preventDefault()

          link.addEventListener('up:link:follow', listener)

          up.follow(link)

          next =>
            expect(listener).toHaveBeenCalled()
            event = listener.calls.mostRecent().args[0]
            expect(event.target).toEqual(link)

            # No request should be made because we prevented the event
            expect(jasmine.Ajax.requests.count()).toEqual(0)

      describe 'history', ->

        it 'adds history entries and allows the user to use the back and forward buttons', asyncSpec (next) ->
          up.history.config.enabled = true

          waitForBrowser = 300

          # By default, up.history will replace the <body> tag when
          # the user presses the back-button. We reconfigure this
          # so we don't lose the Jasmine runner interface.
          up.history.config.restoreTargets = ['.container']

          respondWith = (html, title) =>
            @respondWith
              status: 200
              contentType: 'text/html'
              responseText: "<div class='container'><div class='target'>#{html}</div></div>"
              responseHeaders: { 'X-Up-Title': JSON.stringify(title) }

  #          followAndRespond = ($link, html, title) ->
  #            promise = up.follow($link)
  #            respondWith(html, title)
  #            promise

          up.fragment.config.navigateOptions.history = true

          $link1 = $fixture('a[href="/one"][up-target=".target"]')
          $link2 = $fixture('a[href="/two"][up-target=".target"]')
          $link3 = $fixture('a[href="/three"][up-target=".target"]')
          $container = $fixture('.container')
          $target = $fixture('.target').appendTo($container).text('original text')

          up.follow($link1.get(0))

          next =>
            respondWith('text from one', 'title from one')

          next =>
            expect('.target').toHaveText('text from one')
            expect(location.pathname).toEqual('/one')
            expect(document.title).toEqual('title from one')

            up.follow($link2.get(0))

          next =>
            respondWith('text from two', 'title from two')

          next =>
            expect('.target').toHaveText('text from two')
            expect(location.pathname).toEqual('/two')
            expect(document.title).toEqual('title from two')

            up.follow($link3.get(0))

          next =>
            respondWith('text from three', 'title from three')

          next =>
            expect('.target').toHaveText('text from three')
            expect(location.pathname).toEqual('/three')
            expect(document.title).toEqual('title from three')

            history.back()

          next.after waitForBrowser, =>
            expect('.target').toHaveText('text from two')
            expect(location.pathname).toEqual('/two')
            expect(document.title).toEqual('title from two')

            history.back()

          next.after waitForBrowser, =>
            expect('.target').toHaveText('text from one')
            expect(location.pathname).toEqual('/one')
            expect(document.title).toEqual('title from one')

            history.forward()

          next.after waitForBrowser, =>
            expect('.target').toHaveText('text from two')
            expect(location.pathname).toEqual('/two')
            expect(document.title).toEqual('title from two')

        it 'renders history when the user clicks on a link, goes back and then clicks on the same link (bugfix)', asyncSpec (next) ->
          up.history.config.enabled = true
          up.history.config.restoreTargets = ['.target']
          waitForBrowser = 300

          linkHTML = """
            <a href="/next" up-target=".target" up-history="false">label</a>
          """
          target = fixture('.target', text: 'old text')
          link = fixture('a[href="/next"][up-target=".target"][up-history=true]')
          up.history.replace('/original')

          next ->
            expect(up.history.location).toMatchURL('/original')
            expect('.target').toHaveText('old text')

            Trigger.clickSequence(link)

          next ->
            jasmine.respondWithSelector('.target', text: 'new text')

          next ->
            expect(up.history.location).toMatchURL('/next')
            expect('.target').toHaveText('new text')

            history.back()

          next.after waitForBrowser, ->
            jasmine.respondWithSelector('.target', text: 'old text')

          next ->
            expect(up.history.location).toMatchURL('/original')
            expect('.target').toHaveText('old text')

            Trigger.clickSequence(link)

          next ->
            # Response was already cached
            expect(up.history.location).toMatchURL('/next')
            expect('.target').toHaveText('new text')

        it 'does not add additional history entries when linking to the current URL', asyncSpec (next) ->
          up.history.config.enabled = true

          # By default, up.history will replace the <body> tag when
          # the user presses the back-button. We reconfigure this
          # so we don't lose the Jasmine runner interface.
          up.history.config.restoreTargets = ['.container']

          up.fragment.config.navigateOptions.history = true

          up.network.config.cacheEvictAge = 0

          waitForBrowser = 150

          respondWith = (text) =>
            @respondWith """
              <div class="container">
                <div class='target'>#{text}</div>
              </div>
            """

          $link1 = $fixture('a[href="/one"][up-target=".target"]')
          $link2 = $fixture('a[href="/two"][up-target=".target"]')
          $container = $fixture('.container')
          $target = $fixture('.target').appendTo($container).text('original text')

          up.follow($link1.get(0))

          next =>
            respondWith('text from one')

          next =>
            expect('.target').toHaveText('text from one')
            expect(location.pathname).toEqual('/one')

            up.follow($link2.get(0))

          next =>
            respondWith('text from two')

          next =>
            expect('.target').toHaveText('text from two')
            expect(location.pathname).toEqual('/two')

            up.follow($link2.get(0))

          next =>
            respondWith('text from two')

          next =>
            expect('.target').toHaveText('text from two')
            expect(location.pathname).toEqual('/two')

            history.back()

          next.after waitForBrowser, =>
            respondWith('restored text from one')

          next =>
            expect('.target').toHaveText('restored text from one')
            expect(location.pathname).toEqual('/one')

            history.forward()

          next.after waitForBrowser, =>
            respondWith('restored text from two')

          next =>
            expect('.target').toHaveText('restored text from two')
            expect(location.pathname).toEqual('/two')

        it 'does add additional history entries when linking to the current URL, but with a different hash', asyncSpec (next) ->
          up.history.config.enabled = true

          # By default, up.history will replace the <body> tag when
          # the user presses the back-button. We reconfigure this
          # so we don't lose the Jasmine runner interface.
          up.history.config.restoreTargets = ['.container']

          up.fragment.config.navigateOptions.history = true

          up.network.config.cacheEvictAge = 0

          waitForBrowser = 150

          respondWith = (text) =>
            @respondWith """
              <div class="container">
                <div class='target'>#{text}</div>
              </div>
            """

          $link1 = $fixture('a[href="/one"][up-target=".target"]')
          $link2 = $fixture('a[href="/two"][up-target=".target"]')
          $link2WithHash = $fixture('a[href="/two#hash"][up-target=".target"]')
          $container = $fixture('.container')
          $target = $fixture('.target').appendTo($container).text('original text')

          up.follow($link1.get(0))

          next =>
            respondWith('text from one')

          next =>
            expect('.target').toHaveText('text from one')
            expect(location.pathname).toEqual('/one')
            expect(location.hash).toEqual('')

            up.follow($link2)

          next =>
            respondWith('text from two')

          next =>
            expect('.target').toHaveText('text from two')
            expect(location.pathname).toEqual('/two')
            expect(location.hash).toEqual('')

            up.follow($link2WithHash.get(0))

          next =>
            respondWith('text from two with hash')

          next =>
            expect('.target').toHaveText('text from two with hash')
            expect(location.pathname).toEqual('/two')
            expect(location.hash).toEqual('#hash')

            history.back()

          next.after waitForBrowser, =>
            respondWith('restored text from two')

          next =>
            expect('.target').toHaveText('restored text from two')
            expect(location.pathname).toEqual('/two')
            expect(location.hash).toEqual('')

            history.forward()

          next.after waitForBrowser, =>
            respondWith('restored text from two with hash')

          next =>
            expect('.target').toHaveText('restored text from two with hash')
            expect(location.pathname).toEqual('/two')
            expect(location.hash).toEqual('#hash')

        it 'does add additional history entries when the user clicks a link, changes the URL with history.replaceState(), then clicks the same link again (bugfix)', asyncSpec (next) ->
          up.history.config.enabled = true
          up.fragment.config.navigateOptions.history = true

          fixture('.target', text: 'old text')
          link = fixture('a[href="/link-path"][up-target=".target"]')

          up.follow(link)

          next ->
            jasmine.respondWithSelector('.target', text: 'new text')

          next ->
            expect('.target').toHaveText('new text')
            expect(location.pathname).toEqual('/link-path')

            history.replaceState({}, '', '/user-path')

            expect(location.pathname).toEqual('/user-path')

            up.follow(link)

          next ->
            expect(location.pathname).toEqual('/link-path')

      describe 'scrolling', ->

        describe 'with { scroll: "target" }', ->

          it 'reveals the target fragment', asyncSpec (next) ->
            $link = $fixture('a[href="/action"][up-target=".target"]')
            $target = $fixture('.target')

            revealStub = spyOn(up, 'reveal').and.returnValue(Promise.resolve())

            up.follow($link.get(0), scroll: 'target')

            next =>
              @respondWith('<div class="target">new text</div>')

            next =>
              expect(revealStub).toHaveBeenCalled()
              expect(revealStub.calls.mostRecent().args[0]).toMatchSelector('.target')

        describe 'with { failScroll: "target" }', ->

          it 'reveals the { failTarget } if the server responds with an error', asyncSpec (next) ->
            link = fixture('a[href="/action"][up-target=".target"][up-fail-target=".fail-target"]')
            target = fixture('.target')
            failTarget = fixture('.fail-target')

            revealStub = spyOn(up, 'reveal').and.returnValue(Promise.resolve())

            up.follow(link, failScroll: "target")

            next ->
              jasmine.respondWith
                status: 500,
                responseText: """
                  <div class="fail-target">
                    Errors here
                  </div>
                  """

            next =>
              expect(revealStub).toHaveBeenCalled()
              expect(revealStub.calls.mostRecent().args[0]).toMatchSelector('.fail-target')

        describe 'with { scroll: string } option', ->

          it 'allows to reveal a different selector', asyncSpec (next) ->
            link = fixture('a[href="/action"][up-target=".target"]')
            target = fixture('.target')
            other = fixture('.other')

            revealStub = spyOn(up, 'reveal').and.returnValue(Promise.resolve())

            up.follow(link, scroll: '.other')

            next ->
              jasmine.respondWith """
                <div class="target">
                  new text
                </div>
                <div class="other">
                  new other
                </div>
              """

            next ->
              expect(revealStub).toHaveBeenCalled()
              expect(revealStub.calls.mostRecent().args[0]).toMatchSelector('.other')

          it 'ignores the { scroll } option for a failed response', asyncSpec (next) ->
            link = fixture('a[href="/action"][up-target=".target"][up-fail-target=".fail-target"]')
            target = fixture('.target')
            failTarget = fixture('.fail-target')
            other = fixture('.other')

            revealStub = spyOn(up, 'reveal').and.returnValue(Promise.resolve())

            up.follow(link, scroll: '.other', failTarget: '.fail-target')

            next ->
              jasmine.respondWith
                status: 500,
                responseText: """
                  <div class="fail-target">
                    Errors here
                  </div>
                  """

            next =>
              expect(revealStub).not.toHaveBeenCalled()

        describe 'with { failScroll } option', ->

          it 'reveals the given selector when the server responds with an error', asyncSpec (next) ->
            link = fixture('a[href="/action"][up-target=".target"][up-fail-target=".fail-target"]')
            target = fixture('.target')
            failTarget = fixture('.fail-target')
            other = fixture('.other')
            failOther = fixture('.fail-other')

            revealStub = spyOn(up, 'reveal').and.returnValue(Promise.resolve())

            up.follow(link, reveal: '.other', failScroll: '.fail-other')

            next ->
              jasmine.respondWith
                status: 500,
                responseText: """
                  <div class="fail-target">
                    Errors here
                  </div>
                  <div class="fail-other">
                    Fail other here
                  </div>
                  """

            next ->
              expect(revealStub).toHaveBeenCalled()
              expect(revealStub.calls.mostRecent().args[0]).toMatchSelector('.fail-other')

        describe 'with { scroll: "restore" } option', ->

          beforeEach ->
            up.history.config.enabled = true

          it "does not reveal, but instead restores the scroll positions of the target's viewport", asyncSpec (next) ->

            $viewport = $fixture('.viewport[up-viewport] .element').css
              'height': '100px'
              'width': '100px'
              'overflow-y': 'scroll'

            followLink = (options = {}) ->
              $link = $viewport.find('.link')
              up.follow($link.get(0), options)

            respond = (linkDestination) =>
              @respondWith """
                <div class="element" style="height: 300px">
                  <a class="link" href="#{linkDestination}" up-target=".element">Link</a>
                </div>
                """

            up.navigate('.element', url: '/foo')

            next =>
              # Provide the content at /foo with a link to /bar in the HTML
              respond('/bar')

            next =>
              $viewport.scrollTop(65)

              # Follow the link to /bar
              followLink()

            next =>
              # Provide the content at /bar with a link back to /foo in the HTML
              respond('/foo')

            next =>
              # Follow the link back to /foo, restoring the scroll position of 65px
              followLink(scroll: 'restore')
              # No need to respond because /foo has been cached before

            next =>
              expect($viewport.scrollTop()).toBeAround(65, 1)

        describe "when the browser is already on the link's destination", ->

          it "doesn't make a request and reveals the target container"

          it "doesn't make a request and reveals the target of a #hash in the URL"

      describe 'with { confirm } option', ->

        it 'follows the link after the user OKs a confirmation dialog', asyncSpec (next) ->
          spyOn(window, 'confirm').and.returnValue(true)
          link = fixture('a[href="/danger"][up-target=".middle"]')
          up.follow(link, confirm: 'Do you really want to go there?')

          next =>
            expect(window.confirm).toHaveBeenCalledWith('Do you really want to go there?')

        it 'does not follow the link if the user cancels the confirmation dialog', asyncSpec (next) ->
          spyOn(window, 'confirm').and.returnValue(false)
          link = fixture('a[href="/danger"][up-target=".middle"]')
          up.follow(link, confirm: 'Do you really want to go there?')

          next =>
            expect(window.confirm).toHaveBeenCalledWith('Do you really want to go there?')

        it 'does not show a confirmation dialog if the option is not a present string', asyncSpec (next) ->
          spyOn(up, 'render').and.returnValue(Promise.resolve())
          spyOn(window, 'confirm')
          link = fixture('a[href="/danger"][up-target=".middle"]')
          up.follow(link, confirm: '')

          next =>
            expect(window.confirm).not.toHaveBeenCalled()
            expect(up.render).toHaveBeenCalled()

        it 'does not show a confirmation dialog when preloading', asyncSpec (next) ->
          spyOn(up, 'render').and.returnValue(Promise.resolve())
          spyOn(window, 'confirm')
          link = fixture('a[href="/danger"][up-target=".middle"]')
          up.follow(link, confirm: 'Are you sure?', preload: true)

          next =>
            expect(window.confirm).not.toHaveBeenCalled()
            expect(up.render).toHaveBeenCalled()

    describe "when the link's [href] is '#'", ->

      it 'does not follow the link', asyncSpec (next) ->
        fixture('.target', text: 'old text')

        link = fixture('a[href="#"][up-target=".target"]')
        promise = up.follow(link)

        next.await ->
          return promiseState(promise)

        next (result) ->
          expect(result.state).toBe('rejected')
          expect('.target').toHaveText('old text')

      it 'does follow the link if it has a local content attribute', asyncSpec (next) ->
        fixture('.target', text: 'old text')

        link = fixture('a[href="#"][up-target=".target"][up-content="new text"]')
        promise = up.follow(link)

        next.await ->
          return promiseState(promise)

        next (result) ->
          expect(result.state).toBe('fulfilled')
          expect('.target').toHaveText('new text')

    describe 'up.link.followOptions()', ->

      it 'parses the render options that would be used to follow the given link', ->
        link = fixture('a[href="/path"][up-method="PUT"][up-layer="new"]')
        options = up.link.followOptions(link)
        expect(options.url).toEqual('/path')
        expect(options.method).toEqual('PUT')
        expect(options.layer).toEqual('new')

      it 'does not render', ->
        spyOn(up, 'render').and.returnValue(Promise.resolve())
        link = fixture('a[href="/path"][up-method="PUT"][up-layer="new"]')
        options = up.link.followOptions(link)
        expect(up.render).not.toHaveBeenCalled()

      it 'parses the link method from a [data-method] attribute so we can replace the Rails UJS adapter with Unpoly', ->
        link = fixture('a[href="/path"][data-method="patch"]')
        options = up.link.followOptions(link)
        expect(options.method).toEqual('PATCH')

      it "prefers a link's [up-href] attribute to its [href] attribute", ->
        link = fixture('a[href="/foo"][up-href="/bar"]')
        options = up.link.followOptions(link)
        expect(options.url).toEqual('/bar')

      it 'parses an [up-on-finished] attribute', ->
        window.onFinishedCallback = jasmine.createSpy('onFinished callback')
        link = fixture('a[href="/path"][up-on-finished="window.onFinishedCallback(this)"]')
        options = up.link.followOptions(link)

        expect(u.isFunction(options.onFinished)).toBe(true)
        options.onFinished()

        expect(window.onFinishedCallback).toHaveBeenCalledWith(link)

        delete window.onFinishedCallback

      it 'parses an [up-background] attribute', ->
        link = fixture('a[href="/foo"][up-background="true"]')
        options = up.link.followOptions(link)
        expect(options.background).toBe(true)

      it 'parses an [up-use-keep] attribute', ->
        link = fixture('a[href="/foo"][up-use-keep="false"]')
        options = up.link.followOptions(link)
        expect(options.useKeep).toBe(false)

      it 'parses an [up-use-hungry] attribute', ->
        link = fixture('a[href="/foo"][up-use-hungry="false"]')
        options = up.link.followOptions(link)
        expect(options.useHungry).toBe(false)

      it 'parses an [up-timeout] attribute', ->
        link = fixture('a[href="/foo"][up-timeout="20_000"]')
        options = up.link.followOptions(link)
        expect(options.timeout).toBe(20000)

      it 'parses an [up-animation] attribute', ->
        link = fixture('a[href="/foo"][up-animation="move-from-top"]')
        options = up.link.followOptions(link)
        expect(options.animation).toBe('move-from-top')

    describe 'up.link.shouldFollowEvent', ->

      buildEvent = (target, attrs) ->
        event = Trigger.createMouseEvent('mousedown', attrs)
        # Cannot change event.target on a native event property, but we can with Object.defineProperty()
        Object.defineProperty(event, 'target', get: -> target)
        event

      it "returns true when the given event's target is the given link itself", ->
        $link = $fixture('a[href="/foo"]')
        event = buildEvent($link[0])
        expect(up.link.shouldFollowEvent(event, $link[0])).toBe(true)

      it "returns true when the given event's target is a non-link child of the given link", ->
        $link = $fixture('a[href="/foo"]')
        $span = $link.affix('span')
        event = buildEvent($span[0])
        expect(up.link.shouldFollowEvent(event, $link[0])).toBe(true)

      it "returns false when the given event's target is a child link of the given link (think [up-expand])", ->
        $link = $fixture('div[up-href="/foo"]')
        $childLink = $link.affix('a[href="/bar"]')
        event = buildEvent($childLink[0])
        expect(up.link.shouldFollowEvent(event, $link[0])).toBe(false)

      it "returns false when the given event's target is a child input of the given link (think [up-expand])", ->
        $link = $fixture('div[up-href="/foo"]')
        $childInput = $link.affix('input[type="text"]')
        event = buildEvent($childInput[0])
        expect(up.link.shouldFollowEvent(event, $link[0])).toBe(false)

    describe 'up.link.makeFollowable', ->

      it "adds [up-follow] to a link that wouldn't otherwise be handled by Unpoly", ->
        $link = $fixture('a[href="/path"]').text('label')
        up.link.makeFollowable($link[0])
        expect($link.attr('up-follow')).toEqual('')

      it "does not add [up-follow] to a link that is already [up-target]", ->
        $link = $fixture('a[href="/path"][up-target=".target"]').text('label')
        up.link.makeFollowable($link[0])
        expect($link.attr('up-follow')).toBeMissing()

    describe 'up.visit', ->

      it 'should have tests'

    describe 'up.link.isFollowable', ->

      it 'returns true for an [up-target] link', ->
        $link = $fixture('a[href="/foo"][up-target=".target"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-follow] link', ->
        $link = $fixture('a[href="/foo"][up-follow]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-layer] link', ->
        $link = $fixture('a[href="/foo"][up-layer="modal"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-follow] link', ->
        $link = $fixture('a[href="/foo"][up-follow]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-preload] link', ->
        $link = $fixture('a[href="/foo"][up-preload]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-instant] link', ->
        $link = $fixture('a[href="/foo"][up-instant]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      if up.migrate.loaded
        it 'returns true for an [up-modal] link', ->
          $link = $fixture('a[href="/foo"][up-modal=".target"]')
          up.hello $link
          expect(up.link.isFollowable($link)).toBe(true)

        it 'returns true for an [up-popup] link', ->
          $link = $fixture('a[href="/foo"][up-popup=".target"]')
          up.hello $link
          expect(up.link.isFollowable($link)).toBe(true)

        it 'returns true for an [up-drawer] link', ->
          $link = $fixture('a[href="/foo"][up-drawer=".target"]')
          up.hello $link
          expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-target] span with [up-href]', ->
        $link = $fixture('span[up-href="/foo"][up-target=".target"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns false if the given link will be handled by the browser', ->
        $link = $fixture('a[href="/foo"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(false)

      it 'returns false if the given link will be handled by Rails UJS', ->
        $link = $fixture('a[href="/foo"][data-method="put"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(false)

      it 'returns true if the given link matches a custom up.link.config.followSelectors', ->
        link = fixture('a.hyperlink[href="/foo"]')
        up.link.config.followSelectors.push('.hyperlink')
        expect(up.link.isFollowable(link)).toBe(true)

      it 'returns true if the given link matches a custom up.link.config.followSelectors, but also has [up-follow=false]', ->
        link = fixture('a.hyperlink[href="/foo"][up-follow="false"]')
        up.link.config.followSelectors.push('.hyperlink')
        expect(up.link.isFollowable(link)).toBe(false)

      it 'returns false for an #anchor link without a path, even if the link has [up-follow]', ->
        link = fixture('a[up-follow][href="#details"]')
        expect(up.link.isFollowable(link)).toBe(false)

      it 'returns false for an #anchor link with a path, even if the link has [up-follow]', ->
        link = fixture('a[up-follow][href="/other/page#details"]')
        expect(up.link.isFollowable(link)).toBe(true)

      it 'returns false for a link with a "javascript:..." [href] attribute, even if the link has [up-follow]', ->
        link = fixture('a[up-follow][href="javascript:foo()"]')
        expect(up.link.isFollowable(link)).toBe(false)

    describe 'up.link.preload', ->

      beforeEach ->
        @requestTarget = => @lastRequest().requestHeaders['X-Up-Target']

      it "loads and caches the given link's destination", asyncSpec (next) ->
        fixture('.target')
        link = fixture('a[href="/path"][up-target=".target"]')

        up.link.preload(link)

        next =>
          cachedPromise = up.cache.get
            url: '/path'
            target: '.target'
            failTarget: 'default-fallback'
            origin: link
          expect(u.isPromise(cachedPromise)).toBe(true)

      it 'accepts options that overrides those options that were parsed from the link', asyncSpec (next) ->
        fixture('.target')
        link = fixture('a[href="/path"][up-target=".target"]')
        up.link.preload(link, url: '/options-path')

        next =>
          cachedPromise = up.cache.get
            url: '/options-path'
            target: '.target'
            failTarget: 'default-fallback'
            origin: link
          expect(u.isPromise(cachedPromise)).toBe(true)

      it 'does not dispatch another request for a link that is currently loading', asyncSpec (next) ->
        link = fixture('a[href="/path"][up-target=".target"]')
        up.follow(link)

        next ->
          expect(jasmine.Ajax.requests.count()).toBe(1)

          up.link.preload(link)

        next ->
          expect(jasmine.Ajax.requests.count()).toBe(1)

      it 'does not update fragments for a link with local content (bugfix)', asyncSpec (next) ->
        target = fixture('.target', text: 'old text')
        link = fixture('a[up-content="new text"][up-target=".target"]')

        up.link.preload(link)

        next ->
          expect('.target').toHaveText('old text')

      it 'does not call an { onRendered } callback', asyncSpec (next) ->
        onRendered = jasmine.createSpy('{ onRendered } callback')
        fixture('.target')
        link = fixture('a[up-href="/path"][up-target=".target"]')

        up.link.preload(link, { onRendered })

        next ->
          jasmine.respondWithSelector('.target')

        next ->
          expect(onRendered).not.toHaveBeenCalled()
          expect(window).not.toHaveUnhandledRejections()

      describe 'for an [up-target] link', ->

        it 'includes the [up-target] selector as an X-Up-Target header if the targeted element is currently on the page', asyncSpec (next) ->
          $fixture('.target')
          $link = $fixture('a[href="/path"][up-target=".target"]')
          up.link.preload($link)
          next => expect(@requestTarget()).toEqual('.target')

        it 'replaces the [up-target] selector as with a fallback and uses that as an X-Up-Target header if the targeted element is not currently on the page', asyncSpec (next) ->
          $link = $fixture('a[href="/path"][up-target=".target"]')
          up.link.preload($link)
          # The default fallback would usually be `body`, but in Jasmine specs we change
          # it to protect the test runner during failures.
          next => expect(@requestTarget()).toEqual('default-fallback')

      describe 'for a link opening a new layer', ->

        beforeEach ->
          up.motion.config.enabled = false

        it 'includes the selector as an X-Up-Target header and does not replace it with a fallback, since the layer frame always exists', asyncSpec (next) ->
          $link = $fixture('a[href="/path"][up-target=".target"][up-layer="new"]')
          up.hello($link)
          up.link.preload($link)
          next => expect(@requestTarget()).toEqual('.target')

        it 'does not create layer elements', asyncSpec (next) ->
          $link = $fixture('a[href="/path"][up-target=".target"][up-layer="modal"]')
          up.hello($link)
          up.link.preload($link)
          next =>
            expect('up-modal').not.toBeAttached()

        it 'does not emit an up:layer:open event', asyncSpec (next) ->
          $link = $fixture('a[href="/path"][up-target=".target"][up-layer="new"]')
          up.hello($link)
          openListener = jasmine.createSpy('listener')
          up.on('up:layer:open', openListener)
          up.link.preload($link)
          next =>
            expect(openListener).not.toHaveBeenCalled()

        it 'does not close a currently open overlay', asyncSpec (next) ->
          $link = $fixture('a[href="/path"][up-target=".target"][up-layer="modal"]')
          up.hello($link)
          closeListener = jasmine.createSpy('listener')
          up.on('up:layer:dismiss', closeListener)

          up.layer.open(mode: 'modal', fragment: '<div class="content">Modal content</div>')

          next =>
            expect('up-modal .content').toBeAttached()

          next =>
            up.link.preload($link)

          next =>
            expect('up-modal .content').toBeAttached()
            expect(closeListener).not.toHaveBeenCalled()

          next =>
            up.layer.dismiss()

          next =>
            expect('up-modal .content').not.toBeAttached()
            expect(closeListener).toHaveBeenCalled()

        it 'does not prevent the opening of other overlays while the request is still pending', asyncSpec (next) ->
          $link = $fixture('a[href="/path"][up-target=".target"][up-layer="modal"]')
          up.hello($link)
          up.link.preload($link)

          next =>
            up.layer.open(mode: 'modal', fragment: '<div class="content">Modal content</div>')

          next =>
            expect('up-modal .content').toBeAttached()

        it 'calls up.request() with a { preload: true } option', asyncSpec (next) ->
          requestSpy = spyOn(up, 'request')

          $link = $fixture('a[href="/path"][up-target=".target"][up-layer="new modal"]')
          up.hello($link)
          up.link.preload($link)

          next =>
            expect(requestSpy).toHaveBeenCalledWith(jasmine.objectContaining(preload: true))

      describe 'aborting', ->

        it 'is not abortable by default', asyncSpec (next) ->
          link = fixture('a[href="/path"][up-target=".target"]')
          up.link.preload(link)

          next ->
            expect(up.network.isBusy()).toBe(true)

            up.fragment.abort()

          next ->
            expect(up.network.isBusy()).toBe(true)

        it 'is abortable with { abortable: true }', asyncSpec (next) ->
          link = fixture('a[href="/path"][up-target=".target"]')
          up.link.preload(link, abortable: true)

          next ->
            expect(up.network.isBusy()).toBe(true)

            up.fragment.abort()

          next ->
            expect(up.network.isBusy()).toBe(false)

  describe 'unobtrusive behavior', ->

    describe 'a[up-target]', ->

      it 'does not follow a form with up-target attribute (bugfix)', asyncSpec (next) ->
        $form = $fixture('form[up-target]')
        up.hello($form)
        followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
        Trigger.clickSequence($form)

        next =>
          expect(followSpy).not.toHaveBeenCalled()

      it 'requests the [href] with AJAX and replaces the [up-target] selector', asyncSpec (next) ->
        $fixture('.target')
        $link = $fixture('a[href="/path"][up-target=".target"]')
        Trigger.clickSequence($link)

        next =>
          @respondWith('<div class="target">new text</div>')

        next =>
          expect('.target').toHaveText('new text')


      it 'adds a history entry', asyncSpec (next) ->
        up.history.config.enabled = true
        up.fragment.config.navigateOptions.history = true

        $fixture('.target')
        $link = $fixture('a[href="/new-path"][up-target=".target"]')
        Trigger.clickSequence($link)

        next =>
          @respondWith('<div class="target">new text</div>')

        next.after 1000, =>
          expect('.target').toHaveText('new text')
          expect(location.pathname).toEqual('/new-path')

      it 'respects a X-Up-Location header that the server sends in case of a redirect', asyncSpec (next) ->
        up.history.config.enabled = true

        $fixture('.target')
        $link = $fixture('a[href="/path"][up-target=".target"][up-history]')
        Trigger.clickSequence($link)

        next =>
          @respondWith
            responseText: '<div class="target">new text</div>'
            responseHeaders: { 'X-Up-Location': '/other/path' }

        next =>
          expect('.target').toHaveText('new text')
          expect(location.pathname).toEqual('/other/path')

      describe 'choice of target layer', ->

        beforeEach ->
          up.motion.config.enabled = false

        it 'updates a target in the same layer as the clicked link', asyncSpec (next) ->
          $fixture('.document').affix('.target').text('old document text')
          up.layer.open(fragment: "<div class='target'>old modal text</div>")

          next =>
            expect('.document .target').toHaveText('old document text')
            expect('up-modal .target').toHaveText('old modal text')

            $linkInModal = $('up-modal-content').affix('a[href="/bar"][up-target=".target"]').text('link label')
            Trigger.clickSequence($linkInModal)

          next =>
            @respondWith '<div class="target">new text from modal link</div>'

          next =>
            expect('.document .target').toHaveText('old document text')
            expect('up-modal .target').toHaveText('new text from modal link')

        describe 'with [up-layer] modifier', ->

          beforeEach ->
            up.motion.config.enabled = false

          it 'allows to name a layer for the update', asyncSpec (next) ->
            $fixture('.document').affix('.target').text('old document text')
            up.layer.open(fragment: "<div class='target'>old modal text</div>")

            next =>
              expect('.document .target').toHaveText('old document text')
              expect('up-modal .target').toHaveText('old modal text')

              $linkInModal = $('up-modal-content').affix('a[href="/bar"][up-target=".target"][up-layer="parent"][up-peel="false"]')
              Trigger.clickSequence($linkInModal)

            next =>
              @respondWith '<div class="target">new text from modal link</div>'

            next =>
              expect('.document .target').toHaveText('new text from modal link')
              expect('up-modal .target').toHaveText('old modal text')

          it 'ignores [up-layer] if the server responds with an error', asyncSpec (next) ->
            $fixture('.document').affix('.target').text('old document text')
            up.layer.open(fragment: "<div class='target'>old modal text</div>")

            next =>
              expect('.document .target').toHaveText('old document text')
              expect('up-modal .target').toHaveText('old modal text')

              $linkInModal = $('up-modal-content').affix('a[href="/bar"][up-target=".target"][up-fail-target=".target"][up-layer="parent"][up-peel="false"]')
              Trigger.clickSequence($linkInModal)

            next =>
              @respondWith
                responseText: '<div class="target">new failure text from modal link</div>'
                status: 500

            next =>
              expect('.document .target').toHaveText('old document text')
              expect('up-modal .target').toHaveText('new failure text from modal link')

          it 'allows to name a layer for a non-200 response using an [up-fail-layer] modifier', asyncSpec (next) ->
            $fixture('.document').affix('.target').text('old document text')
            up.layer.open(fragment: "<div class='target'>old modal text</div>")

            next =>
              expect('.document .target').toHaveText('old document text')
              expect('up-modal .target').toHaveText('old modal text')

              $linkInModal = $('up-modal-content').affix('a[href="/bar"][up-target=".target"][up-fail-target=".target"][up-fail-layer="parent"][up-fail-peel="false"]')
              Trigger.clickSequence($linkInModal)

            next =>
              @respondWith
                responseText: '<div class="target">new failure text from modal link</div>'
                status: 500

            next =>
              expect('.document .target').toHaveText('new failure text from modal link')
              expect('up-modal .target').toHaveText('old modal text')

      describe 'with [up-fail-target] modifier', ->

        beforeEach ->
          $fixture('.success-target').text('old success text')
          $fixture('.failure-target').text('old failure text')
          @$link = $fixture('a[href="/path"][up-target=".success-target"][up-fail-target=".failure-target"]')

        it 'uses the [up-fail-target] selector for a failed response', asyncSpec (next) ->
          Trigger.clickSequence(@$link)

          next =>
            @respondWith('<div class="failure-target">new failure text</div>', status: 500)

          next =>
            expect('.success-target').toHaveText('old success text')
            expect('.failure-target').toHaveText('new failure text')

            # Since there isn't anyone who could handle the rejection inside
            # the event handler, our handler mutes the rejection.
            expect(window).not.toHaveUnhandledRejections()


        it 'uses the [up-target] selector for a successful response', asyncSpec (next) ->
          Trigger.clickSequence(@$link)

          next =>
            @respondWith('<div class="success-target">new success text</div>', status: 200)

          next =>
            expect('.success-target').toHaveText('new success text')
            expect('.failure-target').toHaveText('old failure text')

      describe 'with [up-transition] modifier', ->

        it 'morphs between the old and new target element', asyncSpec (next) ->
          fixture('.target.old')
          link = fixture('a[href="/path"][up-target=".target"][up-transition="cross-fade"][up-duration="600"][up-easing="linear"]')
          Trigger.clickSequence(link)

          next =>
            jasmine.respondWith '<div class="target new">new text</div>'

          next =>
            @oldGhost = document.querySelector('.target.old')
            @newGhost = document.querySelector('.target.new')
            expect(@oldGhost).toBeAttached()
            expect(@newGhost).toBeAttached()
            expect(@oldGhost).toHaveOpacity(1, 0.15)
            expect(@newGhost).toHaveOpacity(0, 0.15)

          next.after 300, =>
            expect(@oldGhost).toHaveOpacity(0.5, 0.15)
            expect(@newGhost).toHaveOpacity(0.5, 0.15)

        it 'does not crash when updating a main element (fix for issue #187)', asyncSpec (next) ->
          fixture('main.target.old')
          link = fixture('a[href="/path"][up-target="main"][up-transition="cross-fade"][up-duration="600"]')
          Trigger.clickSequence(link)

          next ->
            jasmine.respondWith '<main class="target new">new text</main>'

          next.after 300, ->
            oldGhost = document.querySelector('main.target.old')
            newGhost = document.querySelector('main.target.new')
            expect(oldGhost).toBeAttached()
            expect(newGhost).toBeAttached()
            expect(oldGhost).toHaveOpacity(0.5, 0.45)
            expect(newGhost).toHaveOpacity(0.5, 0.45)

          next.after 600, ->
            expect(document).toHaveSelector('main.target.new')
            expect(document).not.toHaveSelector('main.target.old')

        it 'does not crash when updating an element that is being transitioned', asyncSpec (next) ->
          $fixture('.target.old', text: 'text 1')
          $link = $fixture('a[href="/path"][up-target=".target"][up-transition="cross-fade"][up-duration="600"][up-easing="linear"]')
          Trigger.clickSequence($link)

          next =>
            jasmine.respondWith('<div class="target">text 2</div>')

          next =>
            expect('.target.old').toBeAttached()
            expect('.target.old').toHaveOpacity(1, 0.15)
            expect('.target.old').toHaveText('text 1')

            expect('.target:not(.old)').toBeAttached()
            expect('.target:not(.old)').toHaveOpacity(0, 0.15)
            expect('.target:not(.old)').toHaveText('text 2')

            up.render('.target', content: 'text 3')

          next.after 300, =>
            expect('.target.old').toHaveOpacity(0.5, 0.15)
            expect('.target.old').toHaveText('text 1')

            expect('.target:not(.old)').toHaveOpacity(0.5, 0.15)
            expect('.target:not(.old)').toHaveText('text 3')


      describe 'wih a CSS selector in the [up-fallback] attribute', ->

        it 'uses the fallback selector if the [up-target] CSS does not exist on the page', asyncSpec (next) ->
          $fixture('.fallback').text('old fallback')
          $link = $fixture('a[href="/path"][up-target=".target"][up-fallback=".fallback"]')
          Trigger.clickSequence($link)

          next =>
            @respondWith """
              <div class="target">new target</div>
              <div class="fallback">new fallback</div>
            """

          next =>
            expect('.fallback').toHaveText('new fallback')

        it 'ignores the fallback selector if the [up-target] CSS exists on the page', asyncSpec (next) ->
          $fixture('.target').text('old target')
          $fixture('.fallback').text('old fallback')
          $link = $fixture('a[href="/path"][up-target=".target"][up-fallback=".fallback"]')
          Trigger.clickSequence($link)

          next =>
            @respondWith """
              <div class="target">new target</div>
              <div class="fallback">new fallback</div>
            """

          next =>
            expect('.target').toHaveText('new target')
            expect('.fallback').toHaveText('old fallback')

      describe 'with [up-content] modifier', ->

        it 'updates a fragment with the given inner HTML string', asyncSpec (next) ->
          target = fixture('.target', text: 'old content')
          link = fixture('a[up-target=".target"][up-content="new content"]')

          Trigger.clickSequence(link)

          next ->
            expect('.target').toHaveText('new content')

        it 'updates a fragment with the given inner HTML string when the element also has an [href="#"] attribute (bugfix)', asyncSpec (next) ->
          target = fixture('.target', text: 'old content')
          link = fixture('a[href="#"][up-target=".target"][up-content="new content"]')

          Trigger.clickSequence(link)

          next ->
            expect('.target').toHaveText('new content')

        it "removes the target's inner HTML with [up-content='']", asyncSpec (next) ->
          target = fixture('.target', text: 'old content')
          link = fixture('a[up-target=".target"][up-content=""]')

          Trigger.clickSequence(link)

          next ->
            expect(document.querySelector('.target').innerHTML).toBe('')

      it 'does not add a history entry when replacing a main target but the up-history attribute is set to "false"', asyncSpec (next) ->
        up.history.config.enabled = true
        up.layer.config.any.mainTargets = ['.target']

        oldPathname = location.pathname
        $fixture('.target')
        $link = $fixture('a[href="/path"][up-target=".target"][up-history="false"]')
        Trigger.clickSequence($link)

        next =>
          @respondWith
            responseText: '<div class="target">new text</div>'
            responseHeaders: { 'X-Up-Location': '/other/path' }

        next =>
          expect('.target').toHaveText('new text')
          expect(location.pathname).toEqual(oldPathname)

    describe 'a[up-follow]', ->

      it "calls up.follow with the clicked link", asyncSpec (next) ->
        @$link = $fixture('a[href="/follow-path"][up-follow]')
        @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

        Trigger.click(@$link)

        next =>
          expect(@followSpy).toHaveBeenCalledWith(@$link[0])
          expect(@$link).not.toHaveBeenDefaultFollowed()

      describe 'exemptions from following', ->

        it 'never follows a link with [download] (which opens a save-as-dialog)', asyncSpec (next) ->
          link = up.hello fixture('a[href="/path"][up-target=".target"][download]')

          Trigger.click(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)
            expect(link).toHaveBeenDefaultFollowed()

        it 'never preloads a link with a [target] attribute (which updates a frame or opens a tab)', asyncSpec (next) ->
          link = up.hello fixture('a[href="/path"][up-target=".target"][target="_blank"]')

          Trigger.click(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)
            expect(link).toHaveBeenDefaultFollowed()

        it 'never follows an a[href="#"]', asyncSpec (next) ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          link = up.hello fixture('a[href="#"][up-target=".target"]')
          clickListener = jasmine.createSpy('click listener')
          up.on('click', clickListener)

          Trigger.click(link)

          next ->
            expect(followSpy).not.toHaveBeenCalled()
            expect(clickListener.calls.argsFor(0)[0].defaultPrevented).toBe(false)

        it 'never follows a link with a "mailto:..." [href] attribute', asyncSpec (next) ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          up.link.config.followSelectors.push('a[href]')
          link = up.hello fixture('a[href="mailto:foo@bar.com"]')

          Trigger.click(link)

          next ->
            expect(followSpy).not.toHaveBeenCalled()
            expect(link).toHaveBeenDefaultFollowed()

        it 'never follows a link with a "whatsapp://..." attribute', asyncSpec (next) ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          up.link.config.followSelectors.push('a[href]')
          link = up.hello fixture('a[href="whatsapp://send?text=Hello"]')

          Trigger.click(link)

          next ->
            expect(followSpy).not.toHaveBeenCalled()
            expect(link).toHaveBeenDefaultFollowed()

        it 'does follow an a[href="#"] if the link also has local content via an [up-content], [up-fragment] or [up-document] attribute', asyncSpec (next) ->
          target = fixture('.target', text: 'old text')
          link = up.hello fixture('a[href="#"][up-target=".target"][up-content="new text"]')

          Trigger.clickSequence(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)
            expect(link).not.toHaveBeenDefaultFollowed()
            expect('.target').toHaveText('new text')

        it 'does nothing if the right mouse button is used', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.click(@$link, button: 2)

          next =>
            expect(@followSpy).not.toHaveBeenCalled()
            expect(@$link).toHaveBeenDefaultFollowed()

        it 'does nothing if shift is pressed during the click', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.click(@$link, shiftKey: true)

          next =>
            expect(@followSpy).not.toHaveBeenCalled()
            expect(@$link).toHaveBeenDefaultFollowed()

        it 'does nothing if ctrl is pressed during the click', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.click(@$link, ctrlKey: true)

          next =>
            expect(@followSpy).not.toHaveBeenCalled()
            expect(@$link).toHaveBeenDefaultFollowed()

        it 'does nothing if meta is pressed during the click', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.click(@$link, metaKey: true)

          next =>
            expect(@followSpy).not.toHaveBeenCalled()
            expect(@$link).toHaveBeenDefaultFollowed()

        it 'does nothing if a listener prevents the up:click event on the link', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          up.on(@$link, 'up:click', (event) -> event.preventDefault())

          Trigger.click(@$link)

          next =>
            expect(@followSpy).not.toHaveBeenCalled()
            expect(@$link).not.toHaveBeenDefaultFollowed()

        it 'does nothing if a listener prevents the click event on the link', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          up.on(@$link, 'click', (event) -> event.preventDefault())

          Trigger.click(@$link)

          next =>
            expect(@followSpy).not.toHaveBeenCalled()
            expect(@$link).not.toHaveBeenDefaultFollowed()

      describe 'handling of up.link.config.followSelectors', ->

        it 'follows matching links even without [up-follow] or [up-target]', asyncSpec (next) ->
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          link = fixture('a[href="/foo"].link')
          up.link.config.followSelectors.push('.link')

          Trigger.click(link)

          next =>
            expect(@followSpy).toHaveBeenCalled()
            expect(link).not.toHaveBeenDefaultFollowed()

        it 'allows to opt out with [up-follow=false]', asyncSpec (next) ->
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          link = fixture('a[href="/foo"][up-follow="false"].link')
          up.link.config.followSelectors.push('.link')

          Trigger.click(link)

          next =>
            expect(@followSpy).not.toHaveBeenCalled()
            expect(link).toHaveBeenDefaultFollowed()

      describe 'with [up-instant] modifier', ->

        it 'follows a link on mousedown (instead of on click)', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.mousedown(@$link)

          next => expect(@followSpy.calls.mostRecent().args[0]).toEqual(@$link[0])

        it 'does nothing on mouseup', asyncSpec (next)->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.mouseup(@$link)

          next => expect(@followSpy).not.toHaveBeenCalled()

        it 'does nothing on click if there was an earlier mousedown event', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.mousedown(@$link)
          Trigger.click(@$link)

          next => expect(@followSpy.calls.count()).toBe(1)

        it 'does follow a link on click if there was never a mousedown event (e.g. if the user pressed enter)', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.click(@$link)

          next => expect(@followSpy.calls.mostRecent().args[0]).toEqual(@$link[0])

        it 'does nothing if the right mouse button is pressed down', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.mousedown(@$link, button: 2)

          next => expect(@followSpy).not.toHaveBeenCalled()

        it 'does nothing if shift is pressed during mousedown', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.mousedown(@$link, shiftKey: true)

          next => expect(@followSpy).not.toHaveBeenCalled()

        it 'does nothing if ctrl is pressed during mousedown', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.mousedown(@$link, ctrlKey: true)

          next => expect(@followSpy).not.toHaveBeenCalled()

        it 'does nothing if meta is pressed during mousedown', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())

          Trigger.mousedown(@$link, metaKey: true)

          next => expect(@followSpy).not.toHaveBeenCalled()

        it 'does nothing if a listener prevents the up:click event on the link', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          up.on(@$link, 'up:click', (event) -> event.preventDefault())

          Trigger.mousedown(@$link)

          next =>
            expect(@followSpy).not.toHaveBeenCalled()
            expect(@$link).not.toHaveBeenDefaultFollowed()

        it 'does nothing if a listener prevents the mousedown event on the link', asyncSpec (next) ->
          @$link = $fixture('a[href="/follow-path"][up-follow][up-instant]')
          @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          up.on(@$link, 'mousedown', (event) -> event.preventDefault())

          Trigger.mousedown(@$link)

          next =>
            expect(@followSpy).not.toHaveBeenCalled()
            expect(@$link).not.toHaveBeenDefaultFollowed()

        it 'fires a click event on an a[href="#"] link that will be handled by the browser', asyncSpec (next) ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          link = up.hello fixture('a[href="#"][up-instant][up-target=".target"]')

          clickListener = jasmine.createSpy('click listener')
          up.on('click', clickListener)

          Trigger.clickSequence(link)

          next ->
            expect(followSpy).not.toHaveBeenCalled()

            expect(clickListener).toHaveBeenCalled()
            expect(clickListener.calls.argsFor(0)[0].defaultPrevented).toBe(false)

        it 'follows a[onclick] links on click instead of mousedown', asyncSpec (next) ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          link = up.hello fixture('a[href="/foo"][onclick="console.log(\'clicked\')"][up-instant][up-target=".target"]')

          Trigger.mousedown(link)

          next ->
            expect(followSpy).not.toHaveBeenCalled()

            Trigger.click(link)

          next ->
            expect(followSpy).toHaveBeenCalled()

        it 'does not fire a click event on an a[href="#"] link that also has local HTML in [up-content], [up-fragment] or [up-document]', asyncSpec (next) ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          # In reality the user will have configured an overly greedy selector like
          # up.fragment.config.instantSelectors.push('a[href]') and we want to help them
          # not break all their "javascript:" links.
          link = up.hello fixture('a[href="#"][up-instant][up-target=".target"][up-content="new content"]')
          fixture('.target')

          clickListener = jasmine.createSpy('click listener')
          up.on('click', clickListener)

          Trigger.clickSequence(link)

          next ->
            expect(followSpy).toHaveBeenCalled()

            expect(clickListener).not.toHaveBeenCalled()
            expect(link).not.toHaveBeenDefaultFollowed()

        it 'fires a click event on an a[href="#hash"] link that will be handled by the browser', asyncSpec (next) ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          # In reality the user will have configured an overly greedy selector like
          # up.fragment.config.instantSelectors.push('a[href]') and we want to help them
          # not break all their #anchor link.s
          link = up.hello fixture('a[href="#details"][up-instant]')

          clickListener = jasmine.createSpy('click listener')
          up.on('click', clickListener)

          Trigger.clickSequence(link)

          next ->
            expect(followSpy).not.toHaveBeenCalled()

            expect(clickListener).toHaveBeenCalled()
            expect(clickListener.calls.argsFor(0)[0].defaultPrevented).toBe(false)

        it 'fires a click event on an a[href="javascript:..."] link that will be handled by the browser', asyncSpec (next) ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          # In reality the user will have configured an overly greedy selector like
          # up.fragment.config.instantSelectors.push('a[href]') and we want to help them
          # not break all their "javascript:" links.
          link = up.hello fixture('a[href="javascript:console.log(\'hi world\')"][up-instant]')

          clickListener = jasmine.createSpy('click listener')
          up.on('click', clickListener)

          Trigger.clickSequence(link)

          next ->
            expect(followSpy).not.toHaveBeenCalled()

            expect(clickListener).toHaveBeenCalled()
            expect(clickListener.calls.argsFor(0)[0].defaultPrevented).toBe(false)

        it 'fires a click event on a cross-origin link that will be handled by the browser', asyncSpec (next) ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          # In reality the user will have configured an overly greedy selector like
          # up.fragment.config.instantSelectors.push('a[href]') and we want to help them
          # not break all their "javascript:" links.
          link = up.hello fixture('a[href="http://other-site.tld/path"][up-instant]')

          clickListener = jasmine.createSpy('click listener')
          up.on('click', clickListener)

          Trigger.clickSequence(link)

          next ->
            expect(followSpy).not.toHaveBeenCalled()

            expect(clickListener).toHaveBeenCalled()
            expect(link).toHaveBeenDefaultFollowed()

        it 'focused the link after the click sequence (like a vanilla link) zzz', ->
          followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
          link = up.hello fixture('a[href="/path"][up-instant]')

          Trigger.clickSequence(link, focus: false)

          expect(followSpy).toHaveBeenCalled()
          expect(link).toBeFocused()

        describe 'handling of up.link.config.instantSelectors', ->

          it 'follows matching links without an [up-instant] attribute', asyncSpec (next) ->
            @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
            link = fixture('a[up-follow][href="/foo"].link')
            up.link.config.instantSelectors.push('.link')

            Trigger.mousedown(link)

            next =>
              expect(@followSpy).toHaveBeenCalled()

          it 'allows individual links to opt out with [up-instant=false]', asyncSpec (next) ->
            @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
            link = fixture('a[up-follow][href="/foo"][up-instant=false].link')
            up.link.config.instantSelectors.push('.link')

            Trigger.mousedown(link)

            next =>
              expect(@followSpy).not.toHaveBeenCalled()

          it 'allows individual links to opt out of all Unpoly link handling with [up-follow=false]', asyncSpec (next) ->
            @followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
            link = fixture('a[up-follow][href="/foo"][up-follow=false].link')
            up.link.config.instantSelectors.push('.link')

            Trigger.mousedown(link)

            next =>
              expect(@followSpy).not.toHaveBeenCalled()

    if up.migrate.loaded

      describe '[up-dash]', ->

        it "is a shortcut for [up-preload], [up-instant] and [up-target], using [up-dash]'s value as [up-target]", ->
          $link = $fixture('a[href="/path"][up-dash=".target"]').text('label')
          up.hello($link)
          expect($link.attr('up-preload')).toEqual('')
          expect($link.attr('up-instant')).toEqual('')
          expect($link.attr('up-target')).toEqual('.target')

        it 'sets [up-follow] instead of [up-target] if no target is given (bugfix)', ->
          link = fixture('a[href="/path"][up-dash]', text: 'label')
          up.hello(link)

          expect(link).not.toHaveAttribute('up-target')
          expect(link).toHaveAttribute('up-follow')

  #      it "adds [up-follow] attribute if [up-dash]'s value is 'true'", ->
  #        $link = $fixture('a[href="/path"][up-dash="true"]').text('label')
  #        up.hello($link)
  #        expect($link.attr('up-follow')).toEqual('')
  #
  #      it "adds [up-follow] attribute if [up-dash] is present, but has no value", ->
  #        $link = $fixture('a[href="/path"][up-dash]').text('label')
  #        up.hello($link)
  #        expect($link.attr('up-follow')).toEqual('')
  #
  #      it "does not add an [up-follow] attribute if [up-dash] is 'true', but [up-target] is present", ->
  #        $link = $fixture('a[href="/path"][up-dash="true"][up-target=".target"]').text('label')
  #        up.hello($link)
  #        expect($link.attr('up-follow')).toBeMissing()
  #        expect($link.attr('up-target')).toEqual('.target')
  #
  #      it "does not add an [up-follow] attribute if [up-dash] is 'true', but [up-modal] is present", ->
  #        $link = $fixture('a[href="/path"][up-dash="true"][up-modal=".target"]').text('label')
  #        up.hello($link)
  #        expect($link.attr('up-follow')).toBeMissing()
  #        expect($link.attr('up-modal')).toEqual('.target')
  #
  #      it "does not add an [up-follow] attribute if [up-dash] is 'true', but [up-popup] is present", ->
  #        $link = $fixture('a[href="/path"][up-dash="true"][up-popup=".target"]').text('label')
  #        up.hello($link)
  #        expect($link.attr('up-follow')).toBeMissing()
  #        expect($link.attr('up-popup')).toEqual('.target')

        it "removes the [up-dash] attribute when it's done", ->
          $link = $fixture('a[href="/path"]').text('label')
          up.hello($link)
          expect($link.attr('up-dash')).toBeMissing()

    describe '[up-expand]', ->

      it 'copies up-related attributes of a contained link', ->
        $area = $fixture('div[up-expand] a[href="/path"][up-target="selector"][up-instant][up-preload]')
        up.hello($area)
        expect($area.attr('up-target')).toEqual('selector')
        expect($area.attr('up-instant')).toEqual('')
        expect($area.attr('up-preload')).toEqual('')

      it "renames a contained link's href attribute to up-href so the container is considered a link", ->
        $area = $fixture('div[up-expand] a[up-follow][href="/path"]')
        up.hello($area)
        expect($area.attr('up-href')).toEqual('/path')

      it 'copies attributes from the first link if there are multiple links', ->
        $area = $fixture('div[up-expand]')
        $link1 = $area.affix('a[href="/path1"]')
        $link2 = $area.affix('a[href="/path2"]')
        up.hello($area)
        expect($area.attr('up-href')).toEqual('/path1')

      it "copies an contained non-link element with up-href attribute", ->
        $area = $fixture('div[up-expand] span[up-follow][up-href="/path"]')
        up.hello($area)
        expect($area.attr('up-href')).toEqual('/path')

      it 'adds an up-follow attribute if the contained link has neither up-follow nor up-target attributes', ->
        $area = $fixture('div[up-expand] a[href="/path"]')
        up.hello($area)
        expect($area.attr('up-follow')).toEqual('')

      it 'can be used to enlarge the click area of a link', asyncSpec (next) ->
        $area = $fixture('div[up-expand] a[href="/path"]')
        up.hello($area)
        spyOn(up, 'render').and.returnValue(Promise.resolve())
        Trigger.clickSequence($area)
        next =>
          expect(up.render).toHaveBeenCalled()

      it 'does nothing when the user clicks another link in the expanded area', asyncSpec (next) ->
        $area = $fixture('div[up-expand]')
        $expandedLink = $area.affix('a[href="/expanded-path"][up-follow]')
        $otherLink = $area.affix('a[href="/other-path"][up-follow]')
        up.hello($area)
        followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
        Trigger.clickSequence($otherLink)
        next =>
          expect(followSpy.calls.count()).toEqual(1)
          expect(followSpy.calls.mostRecent().args[0]).toEqual($otherLink[0])

      it 'does nothing when the user clicks on an input in the expanded area', asyncSpec (next) ->
        $area = $fixture('div[up-expand]')
        $expandedLink = $area.affix('a[href="/expanded-path"][up-follow]')
        $input = $area.affix('input[name=email][type=text]')
        up.hello($area)
        followSpy = up.link.follow.mock().and.returnValue(Promise.resolve())
        Trigger.clickSequence($input)
        next =>
          expect(followSpy).not.toHaveBeenCalled()

      it 'does not trigger multiple replaces when the user clicks on the expanded area of an [up-instant] link (bugfix)', asyncSpec (next) ->
        $area = $fixture('div[up-expand] a[href="/path"][up-follow][up-instant]')
        up.hello($area)
        spyOn(up, 'render').and.returnValue(Promise.resolve())
        Trigger.clickSequence($area)
        next =>
          expect(up.render.calls.count()).toEqual(1)

      if up.migrate.loaded
        it 'makes the expanded area followable if the expanded link is [up-dash] with a selector (bugfix)', ->
          $area = $fixture('div[up-expand] a[href="/path"][up-dash=".element"]')
          up.hello($area)
          expect($area).toBeFollowable()
          expect($area.attr('up-target')).toEqual('.element')

        it 'makes the expanded area followable if the expanded link is [up-dash] without a selector (bugfix)', ->
          $area = $fixture('div[up-expand] a[href="/path"][up-dash]')
          up.hello($area)
          expect($area).toBeFollowable()

      describe 'with a CSS selector in the property value', ->

        it "expands the contained link that matches the selector", ->
          $area = $fixture('div[up-expand=".second"]')
          $link1 = $area.affix('a.first[href="/path1"]')
          $link2 = $area.affix('a.second[href="/path2"]')
          up.hello($area)
          expect($area.attr('up-href')).toEqual('/path2')

        it 'does nothing if no contained link matches the selector', ->
          $area = $fixture('div[up-expand=".foo"]')
          $link = $area.affix('a[href="/path1"]')
          up.hello($area)
          expect($area.attr('up-href')).toBeUndefined()

        it 'does not match an element that is not a descendant', ->
          $area = $fixture('div[up-expand=".second"]')
          $link1 = $area.affix('a.first[href="/path1"]')
          $link2 = $fixture('a.second[href="/path2"]') # not a child of $area
          up.hello($area)
          expect($area.attr('up-href')).toBeUndefined()

    describe '[up-preload]', ->

      beforeEach ->
        # Disable response time measuring for these tests
        up.network.config.preloadEnabled = true

      it 'preloads the link destination when hovering, after a delay', asyncSpec (next) ->
        up.link.config.preloadDelay = 100

        $fixture('.target').text('old text')

        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)

        Trigger.hoverSequence($link)

        next.after 50, =>
          # It's still too early
          expect(jasmine.Ajax.requests.count()).toEqual(0)

        next.after 75, =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)
          expect(@lastRequest().url).toMatchURL('/foo')
          expect(@lastRequest()).toHaveRequestMethod('GET')
          expect(@lastRequest().requestHeaders['X-Up-Target']).toEqual('.target')

          @respondWith """
            <div class="target">
              new text
            </div>
            """

        next =>
          # We only preloaded, so the target isn't replaced yet.
          expect('.target').toHaveText('old text')

          Trigger.clickSequence($link)

        next =>
          # No additional request has been sent since we already preloaded
          expect(jasmine.Ajax.requests.count()).toEqual(1)

          # The target is replaced instantly
          expect('.target').toHaveText('new text')

      it 'does not send a request if the user stops hovering before the delay is over', asyncSpec (next) ->
        up.link.config.preloadDelay = 100

        $fixture('.target').text('old text')

        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)

        Trigger.hoverSequence($link)

        next.after 40, =>
          # It's still too early
          expect(jasmine.Ajax.requests.count()).toEqual(0)

          Trigger.unhoverSequence($link)

        next.after 90, =>
          expect(jasmine.Ajax.requests.count()).toEqual(0)

      it 'does not send a request if the link was detached before the delay is over', asyncSpec (next) ->
        up.link.config.preloadDelay = 100

        $fixture('.target').text('old text')

        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)

        Trigger.hoverSequence($link)

        next.after 40, =>
          # It's still too early
          expect(jasmine.Ajax.requests.count()).toEqual(0)

          $link.remove()

        next.after 90, =>
          expect(jasmine.Ajax.requests.count()).toEqual(0)
          expect(window).not.toHaveUnhandledRejections()

      it 'aborts a preload request if the user stops hovering before the response was received', asyncSpec (next) ->
        up.link.config.preloadDelay = 10
        $fixture('.target').text('old text')
        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)
        abortListener = jasmine.createSpy('up:request:aborted listener')
        up.on('up:request:aborted', abortListener)

        Trigger.hoverSequence($link)

        next.after 50, ->
          expect(abortListener).not.toHaveBeenCalled()
          expect(jasmine.Ajax.requests.count()).toEqual(1)

          Trigger.unhoverSequence($link)

        next.after 50, ->
          expect(abortListener).toHaveBeenCalled()

      it 'does not abort a request if the user followed the link while it was preloading, and then stopped hovering', asyncSpec (next) ->
        up.link.config.preloadDelay = 10
        $fixture('.target').text('old text')
        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)
        abortListener = jasmine.createSpy('up:request:aborted listener')
        up.on('up:request:aborted', abortListener)

        Trigger.hoverSequence($link)

        next.after 50, ->
          expect(abortListener).not.toHaveBeenCalled()
          expect(jasmine.Ajax.requests.count()).toEqual(1)

          Trigger.click($link)

        next ->
          expect(abortListener).not.toHaveBeenCalled()

          Trigger.unhoverSequence($link)

        next ->
          expect(abortListener).not.toHaveBeenCalled()

      it 'preloads the link destination on touchstart (without delay)', asyncSpec (next) ->
        up.link.config.preloadDelay = 100

        $fixture('.target').text('old text')

        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)

        Trigger.touchstart($link)

        next =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)
          expect(@lastRequest().url).toMatchURL('/foo')
          expect(@lastRequest()).toHaveRequestMethod('GET')
          expect(@lastRequest().requestHeaders['X-Up-Target']).toEqual('.target')

          @respondWith """
            <div class="target">
              new text
            </div>
            """

        next =>
          # We only preloaded, so the target isn't replaced yet.
          expect('.target').toHaveText('old text')

          Trigger.click($link)

        next =>
          # No additional request has been sent since we already preloaded
          expect(jasmine.Ajax.requests.count()).toEqual(1)

          # The target is replaced instantly
          expect('.target').toHaveText('new text')

      it 'registers the touchstart callback as a passive event listener', ->
        fixture('.target')
        link = fixture('a[href="/foo"][up-target=".target"][up-preload]')

        spyOn(link, 'addEventListener')

        up.hello(link)

        expect(link.addEventListener).toHaveBeenCalledWith('touchstart', jasmine.any(Function), { passive: true })

      it 'preloads the link destination on mousedown (without delay)', asyncSpec (next) ->
        up.link.config.preloadDelay = 100

        $fixture('.target').text('old text')

        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)

        Trigger.mousedown($link)

        next =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)
          expect(@lastRequest().url).toMatchURL('/foo')
          expect(@lastRequest()).toHaveRequestMethod('GET')
          expect(@lastRequest().requestHeaders['X-Up-Target']).toEqual('.target')

          @respondWith """
            <div class="target">
              new text
            </div>
            """

        next =>
          # We only preloaded, so the target isn't replaced yet.
          expect('.target').toHaveText('old text')

          Trigger.click($link)

        next =>
          # No additional request has been sent since we already preloaded
          expect(jasmine.Ajax.requests.count()).toEqual(1)

          # The target is replaced instantly
          expect('.target').toHaveText('new text')

      it 'does not cache a failed response', asyncSpec (next) ->
        up.link.config.preloadDelay = 0

        $fixture('.target').text('old text')

        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)

        Trigger.hoverSequence($link)

        next.after 50, =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)

          @respondWith
            status: 500
            responseText: """
              <div class="target">
                new text
              </div>
              """

        next =>
          # We only preloaded, so the target isn't replaced yet.
          expect('.target').toHaveText('old text')

          Trigger.click($link)

        next =>
          # Since the preloading failed, we send another request
          expect(jasmine.Ajax.requests.count()).toEqual(2)

          # Since there isn't anyone who could handle the rejection inside
          # the event handler, our handler mutes the rejection.
          expect(window).not.toHaveUnhandledRejections()

      describe 'exemptions from preloading', ->

        beforeEach ->
          up.link.config.preloadDelay = 0
          $fixture('.target')

        it "never preloads a link with an unsafe method", asyncSpec (next) ->
          link = up.hello fixture('a[href="/path"][up-target=".target"][up-preload][data-method="post"]')

          Trigger.hoverSequence(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)

        it 'never preloads a link that has been marked with [up-cache=false]', asyncSpec (next) ->
          link = up.hello fixture('a[href="/no-auto-caching-path"][up-cache=false]')

          Trigger.hoverSequence(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)

        it 'never preloads a link that does not auto-cache', asyncSpec (next) ->
          up.network.config.autoCache = (request) ->
            expect(request).toEqual jasmine.any(up.Request)
            return request.url != '/no-auto-caching-path'

          link = up.hello fixture('a[href="/no-auto-caching-path"][up-preload][up-target=".target"]')

          Trigger.hoverSequence(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)

        it "never preloads a link with cross-origin [href]", asyncSpec (next) ->
          link = up.hello fixture('a[href="https://other-domain.com/path"][up-preload][up-target=".target"]')

          Trigger.hoverSequence(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)

        it 'never preloads a link with [download] (which opens a save-as-dialog)', asyncSpec (next) ->
          link = up.hello fixture('a[href="/path"][up-target=".target"][up-preload][download]')

          Trigger.hoverSequence(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)

        it 'never preloads a link with a [target] attribute (which updates a frame or opens a tab)', asyncSpec (next) ->
          link = up.hello fixture('a[href="/path"][up-target=".target"][up-preload][target="_blank"]')

          Trigger.hoverSequence(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)

        it 'never preloads a link with [href="#"]', asyncSpec (next) ->
          link = up.hello fixture('a[href="#"][up-preload]')

          Trigger.hoverSequence(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)

        it 'never preloads a link with local content via [up-content]', asyncSpec (next) ->
          fixture('.target', text: 'old text')
          link = up.hello fixture('a[up-preload][up-content="new text"][up-target=".target"]')

          Trigger.hoverSequence(link)

          next ->
            expect(jasmine.Ajax.requests.count()).toBe(0)

            Trigger.clickSequence(link)

          next ->
            expect('.target').toHaveText('new text')

        describeFallback 'canPushState', ->

          it "does not preload a link", asyncSpec (next) ->
            fixture('.target')
            link = up.hello fixture('a[href="/path"][up-target=".target"][up-preload]')

            Trigger.hoverSequence(link)

            next ->
              expect(jasmine.Ajax.requests.count()).toBe(0)

      describe 'handling of up.link.config.preloadSelectors', ->

        beforeEach ->
          up.link.config.preloadDelay = 0

        it 'preload matching links without an [up-preload] attribute', asyncSpec (next) ->
          up.link.config.preloadSelectors.push('.link')
          link = fixture('a[up-follow][href="/foo"].link')
          up.hello(link)

          Trigger.hoverSequence(link)
          next ->
            expect(jasmine.Ajax.requests.count()).toEqual(1)

        it 'allows individual links to opt out with [up-preload=false]', asyncSpec (next) ->
          up.link.config.preloadSelectors.push('.link')
          link = fixture('a[up-follow][href="/foo"][up-preload=false].link')
          up.hello(link)

          Trigger.hoverSequence(link)
          next ->
            expect(jasmine.Ajax.requests.count()).toEqual(0)

        it 'allows individual links to opt out of all Unpoly link handling with [up-follow=false]', asyncSpec (next) ->
          up.link.config.preloadSelectors.push('.link')
          link = fixture('a[up-follow][href="/foo"][up-follow=false].link')
          up.hello(link)

          Trigger.hoverSequence(link)
          next ->
            expect(jasmine.Ajax.requests.count()).toEqual(0)


  describe 'up:click', ->

    describe 'on a link that is not [up-instant]', ->

      it 'emits an up:click event on click', ->
        link = fixture('a[href="/path"]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.click(link)
        expect(listener).toHaveBeenCalled()
        expect(link).toHaveBeenDefaultFollowed()

      it 'does not crash with a synthetic click event that may not have all properties defined (bugfix)', ->
        link = fixture('a[href="/path"]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.click(link, {
          clientX: undefined,
          clientY: undefined,
          screenX: undefined,
          screenY: undefined,
        })
        expect(listener).toHaveBeenCalled()
        expect(link).toHaveBeenDefaultFollowed()

      it 'prevents the click event when the up:click event is prevented', ->
        clickEvent = null
        link = fixture('a[href="/path"]')
        link.addEventListener('click', (event) -> clickEvent = event)
        link.addEventListener('up:click', (event) -> event.preventDefault())
        Trigger.click(link)
        expect(clickEvent.defaultPrevented).toBe(true)

      it 'does not emit an up:click event if an element has covered the click coordinates on mousedown, which would cause browsers to create a click event on body', asyncSpec (next) ->
        link = fixture('a[href="/path"]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        link.addEventListener('mousedown', ->
          up.layer.open(mode: 'cover', content: 'cover text')
        )
        Trigger.mousedown(link)

        next ->
          expect(up.layer.mode).toBe('cover')
          Trigger.click(link)

        next ->
          expect(listener).not.toHaveBeenCalled()
          expect(link).toHaveBeenDefaultFollowed()

      it 'does not emit an up:click event if the right mouse button is used', asyncSpec (next) ->
        link = fixture('a[href="/path"]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.click(link, button: 2)
        next ->
          expect(listener).not.toHaveBeenCalled()
          expect(link).toHaveBeenDefaultFollowed()

      it 'does not emit an up:click event if shift is pressed during the click', asyncSpec (next) ->
        link = fixture('a[href="/path"]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.click(link, shiftKey: true)
        next ->
          expect(listener).not.toHaveBeenCalled()
          expect(link).toHaveBeenDefaultFollowed()

      it 'does not emit an up:click event if ctrl is pressed during the click', asyncSpec (next) ->
        link = fixture('a[href="/path"]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.click(link, ctrlKey: true)
        next ->
          expect(listener).not.toHaveBeenCalled()
          expect(link).toHaveBeenDefaultFollowed()

      it 'does not emit an up:click event if meta is pressed during the click', asyncSpec (next) ->
        link = fixture('a[href="/path"]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.click(link, metaKey: true)
        next ->
          expect(listener).not.toHaveBeenCalled()
          expect(link).toHaveBeenDefaultFollowed()

      it 'emits a prevented up:click event if the click was already prevented', asyncSpec (next) ->
        link = fixture('a[href="/path"]')
        link.addEventListener('click', (event) -> event.preventDefault())
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.click(link)
        expect(listener).toHaveBeenCalled()
        expect(listener.calls.argsFor(0)[0].defaultPrevented).toBe(true)

    describe 'on a link that is [up-instant]', ->

      it 'emits an up:click event on mousedown', ->
        link = fixture('a[href="/path"][up-instant]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.mousedown(link)
        expect(listener).toHaveBeenCalled()

      it 'does not emit an up:click event on click if there was an earlier mousedown event that was default-prevented', ->
        link = fixture('a[href="/path"][up-instant]')
        listener = jasmine.createSpy('up:click listener')
        Trigger.mousedown(link)
        link.addEventListener('up:click', listener)
        Trigger.click(link)
        expect(listener).not.toHaveBeenCalled()

      it 'prevents a click event if there was an earlier mousedown event that was converted to an up:click', ->
        link = fixture('a[href="/path"][up-instant]')
        clickListener = jasmine.createSpy('click listener')
        link.addEventListener('click', clickListener)
        Trigger.mousedown(link)
        Trigger.click(link)
        expect(clickListener.calls.argsFor(0)[0].defaultPrevented).toBe(true)

      it 'does not emit multiple up:click events in a click sequence', ->
        link = fixture('a[href="/path"][up-instant]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.clickSequence(link)
        expect(listener.calls.count()).toBe(1)

      it "does emit an up:click event on click if there was an earlier mousedown event that was not default-prevented (happens when the user CTRL+clicks and Unpoly won't follow)", ->
        link = fixture('a[href="/path"][up-instant]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.mousedown(link)
        Trigger.click(link)
        expect(listener).toHaveBeenCalled()

      it 'does emit an up:click event if there was a click without mousedown (happens when a link is activated with the Enter key)', ->
        link = fixture('a[href="/path"][up-instant]')
        listener = jasmine.createSpy('up:click listener')
        link.addEventListener('up:click', listener)
        Trigger.click(link)
        expect(listener).toHaveBeenCalled()

      it 'prevents the mousedown event when the up:click event is prevented', ->
        mousedownEvent = null
        link = fixture('a[href="/path"][up-instant]')
        link.addEventListener('mousedown', (event) -> mousedownEvent = event)
        link.addEventListener('up:click', (event) -> event.preventDefault())
        Trigger.mousedown(link)
        expect(mousedownEvent.defaultPrevented).toBe(true)

    describe 'on an non-link element that is [up-instant]', ->

      it 'emits an up:click event on mousedown', ->
        div = fixture('div[up-instant]')
        listener = jasmine.createSpy('up:click listener')
        div.addEventListener('up:click', listener)
        Trigger.mousedown(div)
        expect(listener).toHaveBeenCalled()

    describe 'on an non-link element that is not [up-instant]', ->

      it 'emits an up:click event on click', ->
        div = fixture('div')
        listener = jasmine.createSpy('up:click listener')
        div.addEventListener('up:click', listener)
        Trigger.click(div)
        expect(listener).toHaveBeenCalled()

      it 'does not emit an up:click event on ANY element if the user has dragged away between mousedown and mouseup', ->
        div = fixture('div')
        other = fixture('div')
        listener = jasmine.createSpy('up:click listener')
        up.on('up:click', listener) # use up.on() instead of addEventListener(), since up.on() cleans up after each test
        Trigger.mousedown(other)
        Trigger.mouseup(div)
        Trigger.click(document.body) # this is the behavior of Chrome and Firefox
        expect(listener).not.toHaveBeenCalled()

      it 'prevents the click event when the up:click event is prevented', ->
        clickEvent = null
        div = fixture('div')
        div.addEventListener('click', (event) -> clickEvent = event)
        div.addEventListener('up:click', (event) -> event.preventDefault())
        Trigger.click(div)
        expect(clickEvent.defaultPrevented).toBe(true)

  describe '[up-clickable]', ->

    it 'makes the element emit up:click events on Enter', ->
      fauxLink = up.hello(fixture('.hyperlink[up-clickable]'))
      clickListener = jasmine.createSpy('up:click listener')
      fauxLink.addEventListener('up:click', clickListener)

      Trigger.keySequence(fauxLink, 'Enter')

      expect(clickListener).toHaveBeenCalled()

    it 'makes the element focusable for keyboard users', ->
      fauxLink = up.hello(fixture('.hyperlink[up-clickable]'))

      expect(fauxLink).toBeKeyboardFocusable()

    it 'gives the element a pointer cursor', ->
      fauxLink = up.hello(fixture('.hyperlink[up-clickable]'))

      expect(getComputedStyle(fauxLink).cursor).toEqual('pointer')

    it 'makes other selectors clickable via up.link.config.clickableSelectors', ->
      up.link.config.clickableSelectors.push('.foo')
      fauxLink = up.hello(fixture('.foo'))

      expect(fauxLink).toBeKeyboardFocusable()
      expect(getComputedStyle(fauxLink).cursor).toEqual('pointer')
      expect(fauxLink).toHaveAttribute('up-clickable')
