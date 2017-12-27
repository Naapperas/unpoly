describe 'up.link', ->

  u = up.util

  describe 'JavaScript functions', ->
  
    describe 'up.follow', ->

      describeCapability 'canPushState', ->

        it 'loads the given link via AJAX and replaces the response in the given target', asyncSpec (next) ->
          affix('.before').text('old-before')
          affix('.middle').text('old-middle')
          affix('.after').text('old-after')
          $link = affix('a[href="/path"][up-target=".middle"]')
    
          up.follow($link)

          next =>
            @respondWith """
              <div class="before">new-before</div>
              <div class="middle">new-middle</div>
              <div class="after">new-after</div>
              """

          next =>
            expect($('.before')).toHaveText('old-before')
            expect($('.middle')).toHaveText('new-middle')
            expect($('.after')).toHaveText('old-after')

        it 'uses the method from a data-method attribute', asyncSpec (next) ->
          $link = affix('a[href="/path"][data-method="PUT"]')
          up.follow($link)

          next =>
            request = @lastRequest()
            expect(request).toHaveRequestMethod('PUT')

        it 'allows to refer to the link itself as "&" in the CSS selector', asyncSpec (next) ->
          $container = affix('div')
          $link1 = $('<a id="first" href="/path" up-target="&">first-link</a>').appendTo($container)
          $link2 = $('<a id="second" href="/path" up-target="&">second-link</a>').appendTo($container)
          up.follow($link2)

          next => @respondWith '<div id="second">second-div</div>'
          next => expect($container.text()).toBe('first-linksecond-div')

        it 'adds history entries and allows the user to use the back- and forward-buttons', asyncSpec (next) ->
          up.history.config.enabled = true

          waitForBrowser = 70

          # By default, up.history will replace the <body> tag when
          # the user presses the back-button. We reconfigure this
          # so we don't lose the Jasmine runner interface.
          up.history.config.popTargets = ['.container']

          respondWith = (html, title) =>
            @lastRequest().respondWith
              status: 200
              contentType: 'text/html'
              responseText: "<div class='container'><div class='target'>#{html}</div></div>"
              responseHeaders: { 'X-Up-Title': title }

#          followAndRespond = ($link, html, title) ->
#            promise = up.follow($link)
#            respondWith(html, title)
#            promise

          $link1 = affix('a[href="/one"][up-target=".target"]')
          $link2 = affix('a[href="/two"][up-target=".target"]')
          $link3 = affix('a[href="/three"][up-target=".target"]')
          $container = affix('.container')
          $target = affix('.target').appendTo($container).text('original text')

          up.follow($link1)

          next =>
            respondWith('text from one', 'title from one')

          next =>
            expect($('.target')).toHaveText('text from one')
            expect(location.pathname).toEqual('/one')
            expect(document.title).toEqual('title from one')

            up.follow($link2)

          next =>
            respondWith('text from two', 'title from two')

          next =>
            expect($('.target')).toHaveText('text from two')
            expect(location.pathname).toEqual('/two')
            expect(document.title).toEqual('title from two')

            up.follow($link3)

          next =>
            respondWith('text from three', 'title from three')

          next =>
            expect($('.target')).toHaveText('text from three')
            expect(location.pathname).toEqual('/three')
            expect(document.title).toEqual('title from three')

            history.back()

          next.after waitForBrowser, =>
            respondWith('restored text from two', 'restored title from two')

          next =>
            expect($('.target')).toHaveText('restored text from two')
            expect(location.pathname).toEqual('/two')
            expect(document.title).toEqual('restored title from two')

            history.back()

          next.after waitForBrowser, =>
            respondWith('restored text from one', 'restored title from one')

          next =>
            expect($('.target')).toHaveText('restored text from one')
            expect(location.pathname).toEqual('/one')
            expect(document.title).toEqual('restored title from one')

            history.forward()

          next.after waitForBrowser, =>
            # Since the response is cached, we don't have to respond
            expect($('.target')).toHaveText('restored text from two', 'restored title from two')
            expect(location.pathname).toEqual('/two')
            expect(document.title).toEqual('restored title from two')

        it 'does not add additional history entries when linking to the current URL', asyncSpec (next) ->
          up.history.config.enabled = true

          # By default, up.history will replace the <body> tag when
          # the user presses the back-button. We reconfigure this
          # so we don't lose the Jasmine runner interface.
          up.history.config.popTargets = ['.container']

          up.proxy.config.cacheExpiry = 0

          respondWith = (text) =>
            @respondWith """
              <div class="container">
                <div class='target'>#{text}</div>
              </div>
            """

          $link1 = affix('a[href="/one"][up-target=".target"]')
          $link2 = affix('a[href="/two"][up-target=".target"]')
          $container = affix('.container')
          $target = affix('.target').appendTo($container).text('original text')

          up.follow($link1)

          next =>
            respondWith('text from one')

          next =>
            expect($('.target')).toHaveText('text from one')
            expect(location.pathname).toEqual('/one')

            up.follow($link2)

          next =>
            respondWith('text from two')

          next =>
            expect($('.target')).toHaveText('text from two')
            expect(location.pathname).toEqual('/two')

            up.follow($link2)

          next =>
            respondWith('text from two')

          next =>
            expect($('.target')).toHaveText('text from two')
            expect(location.pathname).toEqual('/two')

            history.back()

          next.after 50, =>
            respondWith('restored text from one')

          next =>
            expect($('.target')).toHaveText('restored text from one')
            expect(location.pathname).toEqual('/one')

            history.forward()

          next.after 50, =>
            respondWith('restored text from two')

          next =>
            expect($('.target')).toHaveText('restored text from two')
            expect(location.pathname).toEqual('/two')

        it 'does adds additional history entries when linking to the current URL, but with a different hash', asyncSpec (next) ->
          up.history.config.enabled = true

          # By default, up.history will replace the <body> tag when
          # the user presses the back-button. We reconfigure this
          # so we don't lose the Jasmine runner interface.
          up.history.config.popTargets = ['.container']

          up.proxy.config.cacheExpiry = 0

          respondWith = (text) =>
            @respondWith """
              <div class="container">
                <div class='target'>#{text}</div>
              </div>
            """

          $link1 = affix('a[href="/one"][up-target=".target"]')
          $link2 = affix('a[href="/two"][up-target=".target"]')
          $link2WithHash = affix('a[href="/two#hash"][up-target=".target"]')
          $container = affix('.container')
          $target = affix('.target').appendTo($container).text('original text')

          up.follow($link1)

          next =>
            respondWith('text from one')

          next =>
            expect($('.target')).toHaveText('text from one')
            expect(location.pathname).toEqual('/one')
            expect(location.hash).toEqual('')

            up.follow($link2)

          next =>
            respondWith('text from two')

          next =>
            expect($('.target')).toHaveText('text from two')
            expect(location.pathname).toEqual('/two')
            expect(location.hash).toEqual('')

            up.follow($link2WithHash)

          next =>
            respondWith('text from two with hash')

          next =>
            expect($('.target')).toHaveText('text from two with hash')
            expect(location.pathname).toEqual('/two')
            expect(location.hash).toEqual('#hash')

            history.back()

          next.after 50, =>
            respondWith('restored text from two')

          next =>
            expect($('.target')).toHaveText('restored text from two')
            expect(location.pathname).toEqual('/two')
            expect(location.hash).toEqual('')

            history.forward()

          next.after 50, =>
            respondWith('restored text from two with hash')

          next =>
            expect($('.target')).toHaveText('restored text from two with hash')
            expect(location.pathname).toEqual('/two')
            expect(location.hash).toEqual('#hash')

        describe 'with { restoreScroll: true } option', ->

          beforeEach ->
            up.history.config.enabled = true

          it 'does not reveal, but instead restores the scroll positions of all viewports around the target', asyncSpec (next) ->

            $viewport = affix('div[up-viewport] .element').css
              'height': '100px'
              'width': '100px'
              'overflow-y': 'scroll'

            followLink = (options = {}) ->
              $link = $viewport.find('.link')
              up.follow($link, options)

            respond = (linkDestination) =>
              @respondWith """
                <div class="element" style="height: 300px">
                  <a class="link" href="#{linkDestination}" up-target=".element">Link</a>
                </div>
                """

            up.replace('.element', '/foo')

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
              followLink(restoreScroll: true)
              # No need to respond because /foo has been cached before

            next =>
              expect($viewport.scrollTop()).toEqual(65)

        describe "when the browser is already on the link's destination", ->

          it "doesn't make a request and reveals the target container"

          it "doesn't make a request and reveals the target of a #hash in the URL"

        describe 'with { confirm } option', ->

          it 'follows the link after the user OKs a confirmation dialog', asyncSpec (next) ->
            spyOn(up, 'replace')
            spyOn(window, 'confirm').and.returnValue(true)
            $link = affix('a[href="/danger"][up-target=".middle"]')
            up.follow($link, confirm: 'Do you really want to go there?')

            next =>
              expect(window.confirm).toHaveBeenCalledWith('Do you really want to go there?')
              expect(up.replace).toHaveBeenCalled()

          it 'does not follow the link if the user cancels the confirmation dialog', asyncSpec (next) ->
            spyOn(up, 'replace')
            spyOn(window, 'confirm').and.returnValue(false)
            $link = affix('a[href="/danger"][up-target=".middle"]')
            up.follow($link, confirm: 'Do you really want to go there?')

            next =>
              expect(window.confirm).toHaveBeenCalledWith('Do you really want to go there?')
              expect(up.replace).not.toHaveBeenCalled()

          it 'does not show a confirmation dialog if the option is not a present string', asyncSpec (next) ->
            spyOn(up, 'replace')
            spyOn(window, 'confirm')
            $link = affix('a[href="/danger"][up-target=".middle"]')
            up.follow($link, confirm: '')

            next =>
              expect(window.confirm).not.toHaveBeenCalled()
              expect(up.replace).toHaveBeenCalled()

          it 'does not show a confirmation dialog when preloading', asyncSpec (next) ->
            spyOn(up, 'replace')
            spyOn(window, 'confirm')
            $link = affix('a[href="/danger"][up-target=".middle"]')
            up.follow($link, confirm: 'Are you sure?', preload: true)

            next =>
              expect(window.confirm).not.toHaveBeenCalled()
              expect(up.replace).toHaveBeenCalled()

      describeFallback 'canPushState', ->

        it 'navigates to the given link without JavaScript', asyncSpec (next) ->
          $link = affix('a[href="/path"]')
          spyOn(up.browser, 'navigate')
          up.follow($link)

          next =>
            expect(up.browser.navigate).toHaveBeenCalledWith('/path', jasmine.anything())

        it 'uses the method from a data-method attribute', asyncSpec (next) ->
          $link = affix('a[href="/path"][data-method="PUT"]')
          spyOn(up.browser, 'navigate')
          up.follow($link)

          next =>
            expect(up.browser.navigate).toHaveBeenCalledWith('/path', { method: 'PUT' })

    describe 'up.link.shouldProcessEvent', ->

      buildEvent = ($element, attrs) ->
        event = Trigger.createMouseEvent('mousedown', attrs)
        event = $.event.fix(event) # convert native event to jQuery event
        event.target = u.unJQuery($element)
        event

      it "returns true when the given event's target is the given link itself", ->
        $link = affix('a[href="/foo"]')
        event = buildEvent($link)
        expect(up.link.shouldProcessEvent(event, $link)).toBe(true)

      it "returns true when the given event's target is a non-link child of the given link", ->
        $link = affix('a[href="/foo"]')
        $span = $link.affix('span')
        event = buildEvent($span)
        expect(up.link.shouldProcessEvent(event, $link)).toBe(true)

      it "returns false when the given event's target is a child link of the given link (think [up-expand])", ->
        $link = affix('div[up-href="/foo"]')
        $childLink = $link.affix('a[href="/bar"]')
        event = buildEvent($childLink)
        expect(up.link.shouldProcessEvent(event, $link)).toBe(false)

      it "returns false when the given event's target is a child input of the given link (think [up-expand])", ->
        $link = affix('div[up-href="/foo"]')
        $childInput = $link.affix('input[type="text"]')
        event = buildEvent($childInput)
        expect(up.link.shouldProcessEvent(event, $link)).toBe(false)

      it 'returns false if the right mouse button is used', ->
        $link = affix('a[href="/foo"]')
        event = buildEvent($link, button: 2)
        expect(up.link.shouldProcessEvent(event, $link)).toBe(false)

      it 'returns false if shift is pressed during the click', ->
        $link = affix('a[href="/foo"]')
        event = buildEvent($link, shiftKey: 2)
        expect(up.link.shouldProcessEvent(event, $link)).toBe(false)

      it 'returns false if ctrl is pressed during the click', ->
        $link = affix('a[href="/foo"]')
        event = buildEvent($link, ctrlKey: 2)
        expect(up.link.shouldProcessEvent(event, $link)).toBe(false)

      it 'returns false if meta is pressed during the click', ->
        $link = affix('a[href="/foo"]')
        event = buildEvent($link, metaKey: 2)
        expect(up.link.shouldProcessEvent(event, $link)).toBe(false)

    describe 'up.link.makeFollowable', ->

      it "adds [up-follow] to a link that wouldn't otherwise be handled by Unpoly", ->
        $link = affix('a[href="/path"]').text('label')
        up.link.makeFollowable($link)
        expect($link.attr('up-follow')).toEqual('')

      it "does not add [up-follow] to a link that is already [up-target]", ->
        $link = affix('a[href="/path"][up-target=".target"]').text('label')
        up.link.makeFollowable($link)
        expect($link.attr('up-follow')).toBeMissing()

      it "does not add [up-follow] to a link that is already [up-modal]", ->
        $link = affix('a[href="/path"][up-modal=".target"]').text('label')
        up.link.makeFollowable($link)
        expect($link.attr('up-follow')).toBeMissing()

      it "does not add [up-follow] to a link that is already [up-popup]", ->
        $link = affix('a[href="/path"][up-popup=".target"]').text('label')
        up.link.makeFollowable($link)
        expect($link.attr('up-follow')).toBeMissing()

    describe 'up.visit', ->

      it 'should have tests'

    describe 'up.link.isFollowable', ->

      it 'returns true for an [up-target] link', ->
        $link = affix('a[href="/foo"][up-target=".target"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-follow] link', ->
        $link = affix('a[href="/foo"][up-follow]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-modal] link', ->
        $link = affix('a[href="/foo"][up-modal=".target"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-popup] link', ->
        $link = affix('a[href="/foo"][up-popup=".target"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-drawer] link', ->
        $link = affix('a[href="/foo"][up-drawer=".target"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns true for an [up-target] span with [up-href]', ->
        $link = affix('span[up-href="/foo"][up-target=".target"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(true)

      it 'returns false if the given link will be handled by the browser', ->
        $link = affix('a[href="/foo"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(false)

      it 'returns false if the given link will be handled by Rails UJS', ->
        $link = affix('a[href="/foo"][data-method="put"]')
        up.hello $link
        expect(up.link.isFollowable($link)).toBe(false)

  describe 'unobtrusive behavior', ->

    describe 'a[up-target]', ->

      it 'does not follow a form with up-target attribute (bugfix)', asyncSpec (next) ->
        $form = affix('form[up-target]')
        up.hello($form)
        followSpy = up.link.knife.mock('defaultFollow').and.returnValue(Promise.resolve())
        Trigger.clickSequence($form)

        next =>
          expect(followSpy).not.toHaveBeenCalled()

      describeCapability 'canPushState', ->

        it 'adds a history entry', asyncSpec (next) ->
          up.history.config.enabled = true

          affix('.target')
          $link = affix('a[href="/path"][up-target=".target"]')
          Trigger.clickSequence($link)

          next =>
            @respondWith('<div class="target">new text</div>')

          next =>
            expect($('.target')).toHaveText('new text')
            expect(location.pathname).toEqual('/path')

        it 'respects a X-Up-Location header that the server sends in case of a redirect', asyncSpec (next) ->
          up.history.config.enabled = true

          affix('.target')
          $link = affix('a[href="/path"][up-target=".target"]')
          Trigger.clickSequence($link)

          next =>
            @respondWith
              responseText: '<div class="target">new text</div>'
              responseHeaders: { 'X-Up-Location': '/other/path' }

          next =>
            expect($('.target')).toHaveText('new text')
            expect(location.pathname).toEqual('/other/path')

        describe 'choice of target layer', ->

          beforeEach ->
            up.motion.config.enabled = false

          it 'prefers to update a container in the same layer as the clicked link', asyncSpec (next) ->
            affix('.document').affix('.target').text('old document text')
            up.modal.extract('.target', "<div class='target'>old modal text</div>")

            next =>
              expect($('.document .target')).toHaveText('old document text')
              expect($('.up-modal .target')).toHaveText('old modal text')

              $linkInModal = $('.up-modal').affix('a[href="/bar"][up-target=".target"]')
              Trigger.clickSequence($linkInModal)

            next =>
              @respondWith '<div class="target">new text from modal link</div>'

            next =>
              expect($('.document .target')).toHaveText('old document text')
              expect($('.up-modal .target')).toHaveText('new text from modal link')

          describe 'with [up-layer] modifier', ->

            it 'allows to name a layer for the update', asyncSpec (next) ->
              affix('.document').affix('.target').text('old document text')
              up.modal.extract('.target', "<div class='target'>old modal text</div>", sticky: true)

              next =>
                expect($('.document .target')).toHaveText('old document text')
                expect($('.up-modal .target')).toHaveText('old modal text')

                $linkInModal = $('.up-modal').affix('a[href="/bar"][up-target=".target"][up-layer="page"]')
                Trigger.clickSequence($linkInModal)

              next =>
                @respondWith '<div class="target">new text from modal link</div>'

              next =>
                expect($('.document .target')).toHaveText('new text from modal link')
                expect($('.up-modal .target')).toHaveText('old modal text')

            it 'ignores [up-layer] if the server responds with a non-200 status code', asyncSpec (next) ->
              affix('.document').affix('.target').text('old document text')
              up.modal.extract('.target', "<div class='target'>old modal text</div>", sticky: true)

              next =>
                expect($('.document .target')).toHaveText('old document text')
                expect($('.up-modal .target')).toHaveText('old modal text')

                $linkInModal = $('.up-modal').affix('a[href="/bar"][up-target=".target"][up-fail-target=".target"][up-layer="page"]')
                Trigger.clickSequence($linkInModal)

              next =>
                @respondWith
                  responseText: '<div class="target">new failure text from modal link</div>'
                  status: 500

              next =>
                expect($('.document .target')).toHaveText('old document text')
                expect($('.up-modal .target')).toHaveText('new failure text from modal link')

            it 'allows to name a layer for a non-200 response using an [up-fail-layer] modifier', asyncSpec (next) ->
              affix('.document').affix('.target').text('old document text')
              up.modal.extract('.target', "<div class='target'>old modal text</div>", sticky: true)

              next =>
                expect($('.document .target')).toHaveText('old document text')
                expect($('.up-modal .target')).toHaveText('old modal text')

                $linkInModal = $('.up-modal').affix('a[href="/bar"][up-target=".target"][up-fail-target=".target"][up-fail-layer="page"]')
                Trigger.clickSequence($linkInModal)

              next =>
                @respondWith
                  responseText: '<div class="target">new failure text from modal link</div>'
                  status: 500

              next =>
                expect($('.document .target')).toHaveText('new failure text from modal link')
                expect($('.up-modal .target')).toHaveText('old modal text')

        describe 'with [up-fail-target] modifier', ->

          beforeEach ->
            affix('.success-target').text('old success text')
            affix('.failure-target').text('old failure text')
            @$link = affix('a[href="/path"][up-target=".success-target"][up-fail-target=".failure-target"]')

          it 'uses the [up-fail-target] selector for a failed response', asyncSpec (next) ->
            Trigger.clickSequence(@$link)

            next =>
              @respondWith('<div class="failure-target">new failure text</div>', status: 500)

            next =>
              expect($('.success-target')).toHaveText('old success text')
              expect($('.failure-target')).toHaveText('new failure text')

          it 'uses the [up-target] selector for a successful response', asyncSpec (next) ->
            Trigger.clickSequence(@$link)

            next =>
              @respondWith('<div class="success-target">new success text</div>', status: 200)

            next =>
              expect($('.success-target')).toHaveText('new success text')
              expect($('.failure-target')).toHaveText('old failure text')

        describe 'with [up-transition] modifier', ->

          it 'morphs between the old and new target element', asyncSpec (next) ->
            affix('.target.old')
            $link = affix('a[href="/path"][up-target=".target"][up-transition="cross-fade"][up-duration="500"][up-easing="linear"]')
            Trigger.clickSequence($link)

            next =>
              @respondWith '<div class="target new">new text</div>'

            next =>
              @$oldGhost = $('.target.old.up-ghost')
              @$newGhost = $('.target.new.up-ghost')
              expect(@$oldGhost).toExist()
              expect(@$newGhost).toExist()
              expect(u.opacity(@$oldGhost)).toBeAround(1, 0.15)
              expect(u.opacity(@$newGhost)).toBeAround(0, 0.15)

            next.after 250, =>
              expect(u.opacity(@$oldGhost)).toBeAround(0.5, 0.15)
              expect(u.opacity(@$newGhost)).toBeAround(0.5, 0.15)

        describe 'wih a CSS selector in the [up-fallback] attribute', ->

          it 'uses the fallback selector if the [up-target] CSS does not exist on the page', asyncSpec (next) ->
            affix('.fallback').text('old fallback')
            $link = affix('a[href="/path"][up-target=".target"][up-fallback=".fallback"]')
            Trigger.clickSequence($link)

            next =>
              @respondWith """
                <div class="target">new target</div>
                <div class="fallback">new fallback</div>
              """

            next =>
              expect('.fallback').toHaveText('new fallback')

          it 'ignores the fallback selector if the [up-target] CSS exists on the page', asyncSpec (next) ->
            affix('.target').text('old target')
            affix('.fallback').text('old fallback')
            $link = affix('a[href="/path"][up-target=".target"][up-fallback=".fallback"]')
            Trigger.clickSequence($link)

            next =>
              @respondWith """
                <div class="target">new target</div>
                <div class="fallback">new fallback</div>
              """

            next =>
              expect('.target').toHaveText('new target')
              expect('.fallback').toHaveText('old fallback')

      it 'does not add a history entry when an up-history attribute is set to "false"', asyncSpec (next) ->
        up.history.config.enabled = true

        oldPathname = location.pathname
        affix('.target')
        $link = affix('a[href="/path"][up-target=".target"][up-history="false"]')
        Trigger.clickSequence($link)

        next =>
          @respondWith
            responseText: '<div class="target">new text</div>'
            responseHeaders: { 'X-Up-Location': '/other/path' }

        next =>
          expect($('.target')).toHaveText('new text')
          expect(location.pathname).toEqual(oldPathname)

    describe 'a[up-follow]', ->

      beforeEach ->
        @$link = affix('a[href="/follow-path"][up-follow]')
        @followSpy = up.link.knife.mock('defaultFollow').and.returnValue(Promise.resolve())
        @defaultSpy = spyOn(up.link, 'allowDefault').and.callFake((event) -> event.preventDefault())

      it "calls up.follow with the clicked link", asyncSpec (next) ->
        Trigger.click(@$link)
        next =>
          expect(@followSpy).toHaveBeenCalledWith(@$link, {})

      # IE does not call JavaScript and always performs the default action on right clicks
      unless AgentDetector.isIE() || AgentDetector.isEdge()
        it 'does nothing if the right mouse button is used', asyncSpec (next) ->
          Trigger.click(@$link, button: 2)
          next => expect(@followSpy).not.toHaveBeenCalled()

      it 'does nothing if shift is pressed during the click', asyncSpec (next) ->
        Trigger.click(@$link, shiftKey: true)
        next => expect(@followSpy).not.toHaveBeenCalled()

      it 'does nothing if ctrl is pressed during the click', asyncSpec (next)->
        Trigger.click(@$link, ctrlKey: true)
        next => expect(@followSpy).not.toHaveBeenCalled()

      it 'does nothing if meta is pressed during the click', asyncSpec (next)->
        Trigger.click(@$link, metaKey: true)
        next => expect(@followSpy).not.toHaveBeenCalled()

      describe 'with [up-instant] modifier', ->

        beforeEach ->
          @$link.attr('up-instant', '')

        it 'follows a link on mousedown (instead of on click)', asyncSpec (next)->
          Trigger.mousedown(@$link)
          next => expect(@followSpy.calls.mostRecent().args[0]).toEqual(@$link)

        it 'does nothing on mouseup', asyncSpec (next)->
          Trigger.mouseup(@$link)
          next => expect(@followSpy).not.toHaveBeenCalled()

        it 'does nothing on click', asyncSpec (next)->
          Trigger.click(@$link)
          next => expect(@followSpy).not.toHaveBeenCalled()

        # IE does not call JavaScript and always performs the default action on right clicks
        unless AgentDetector.isIE() || AgentDetector.isEdge()
          it 'does nothing if the right mouse button is pressed down', asyncSpec (next)->
            Trigger.mousedown(@$link, button: 2)
            next => expect(@followSpy).not.toHaveBeenCalled()

        it 'does nothing if shift is pressed during mousedown', asyncSpec (next) ->
          Trigger.mousedown(@$link, shiftKey: true)
          next => expect(@followSpy).not.toHaveBeenCalled()

        it 'does nothing if ctrl is pressed during mousedown', asyncSpec (next) ->
          Trigger.mousedown(@$link, ctrlKey: true)
          next => expect(@followSpy).not.toHaveBeenCalled()

        it 'does nothing if meta is pressed during mousedown', asyncSpec (next) ->
          Trigger.mousedown(@$link, metaKey: true)
          next => expect(@followSpy).not.toHaveBeenCalled()

    describe '[up-dash]', ->

      it "is a shortcut for [up-preload], [up-instant] and [up-target], using [up-dash]'s value as [up-target]", ->
        $link = affix('a[href="/path"][up-dash=".target"]').text('label')
        up.hello($link)
        expect($link.attr('up-preload')).toEqual('')
        expect($link.attr('up-instant')).toEqual('')
        expect($link.attr('up-target')).toEqual('.target')

      it "adds [up-follow] attribute if [up-dash]'s value is 'true'", ->
        $link = affix('a[href="/path"][up-dash="true"]').text('label')
        up.hello($link)
        expect($link.attr('up-follow')).toEqual('')

      it "adds [up-follow] attribute if [up-dash] is present, but has no value", ->
        $link = affix('a[href="/path"][up-dash]').text('label')
        up.hello($link)
        expect($link.attr('up-follow')).toEqual('')

      it "does not add an [up-follow] attribute if [up-dash] is 'true', but [up-target] is present", ->
        $link = affix('a[href="/path"][up-dash="true"][up-target=".target"]').text('label')
        up.hello($link)
        expect($link.attr('up-follow')).toBeMissing()
        expect($link.attr('up-target')).toEqual('.target')

      it "does not add an [up-follow] attribute if [up-dash] is 'true', but [up-modal] is present", ->
        $link = affix('a[href="/path"][up-dash="true"][up-modal=".target"]').text('label')
        up.hello($link)
        expect($link.attr('up-follow')).toBeMissing()
        expect($link.attr('up-modal')).toEqual('.target')

      it "does not add an [up-follow] attribute if [up-dash] is 'true', but [up-popup] is present", ->
        $link = affix('a[href="/path"][up-dash="true"][up-popup=".target"]').text('label')
        up.hello($link)
        expect($link.attr('up-follow')).toBeMissing()
        expect($link.attr('up-popup')).toEqual('.target')

      it "removes the [up-dash] attribute when it's done", ->
        $link = affix('a[href="/path"]').text('label')
        up.hello($link)
        expect($link.attr('up-dash')).toBeMissing()

    describe '[up-expand]', ->

      it 'copies up-related attributes of a contained link', ->
        $area = affix('div[up-expand] a[href="/path"][up-target="selector"][up-instant][up-preload]')
        up.hello($area)
        expect($area.attr('up-target')).toEqual('selector')
        expect($area.attr('up-instant')).toEqual('')
        expect($area.attr('up-preload')).toEqual('')

      it "renames a contained link's href attribute to up-href so the container is considered a link", ->
        $area = affix('div[up-expand] a[up-follow][href="/path"]')
        up.hello($area)
        expect($area.attr('up-href')).toEqual('/path')

      it 'copies attributes from the first link if there are multiple links', ->
        $area = affix('div[up-expand]')
        $link1 = $area.affix('a[href="/path1"]')
        $link2 = $area.affix('a[href="/path2"]')
        up.hello($area)
        expect($area.attr('up-href')).toEqual('/path1')

      it "copies an contained non-link element with up-href attribute", ->
        $area = affix('div[up-expand] span[up-follow][up-href="/path"]')
        up.hello($area)
        expect($area.attr('up-href')).toEqual('/path')

      it 'adds an up-follow attribute if the contained link has neither up-follow nor up-target attributes', ->
        $area = affix('div[up-expand] a[href="/path"]')
        up.hello($area)
        expect($area.attr('up-follow')).toEqual('')

      it 'can be used to enlarge the click area of a link', asyncSpec (next) ->
        $area = affix('div[up-expand] a[href="/path"]')
        up.hello($area)
        spyOn(up, 'replace')
        Trigger.clickSequence($area)
        next =>
          expect(up.replace).toHaveBeenCalled()

      it 'does nothing when the user clicks another link in the expanded area', asyncSpec (next) ->
        $area = affix('div[up-expand]')
        $expandedLink = $area.affix('a[href="/expanded-path"][up-follow]')
        $otherLink = $area.affix('a[href="/other-path"][up-follow]')
        up.hello($area)
        followSpy = up.link.knife.mock('defaultFollow').and.returnValue(Promise.resolve())
        Trigger.clickSequence($otherLink)
        next =>
          expect(followSpy.calls.count()).toEqual(1)
          expect(followSpy.calls.mostRecent().args[0]).toEqual($otherLink)

      it 'does nothing when the user clicks on an input in the expanded area', asyncSpec (next) ->
        $area = affix('div[up-expand]')
        $expandedLink = $area.affix('a[href="/expanded-path"][up-follow]')
        $input = $area.affix('input[type=text]')
        up.hello($area)
        followSpy = up.link.knife.mock('defaultFollow').and.returnValue(Promise.resolve())
        Trigger.clickSequence($input)
        next =>
          expect(followSpy).not.toHaveBeenCalled()

      it 'does not trigger multiple replaces when the user clicks on the expanded area of an [up-instant] link (bugfix)', asyncSpec (next) ->
        $area = affix('div[up-expand] a[href="/path"][up-follow][up-instant]')
        up.hello($area)
        spyOn(up, 'replace')
        Trigger.clickSequence($area)
        next =>
          expect(up.replace.calls.count()).toEqual(1)

      it 'does not add an up-follow attribute if the expanded link is [up-dash] with a selector (bugfix)', ->
        $area = affix('div[up-expand] a[href="/path"][up-dash=".element"]')
        up.hello($area)
        expect($area.attr('up-follow')).toBeMissing()

      it 'does not an up-follow attribute if the expanded link is [up-dash] without a selector (bugfix)', ->
        $area = affix('div[up-expand] a[href="/path"][up-dash]')
        up.hello($area)
        expect($area.attr('up-follow')).toEqual('')

      describe 'with a CSS selector in the property value', ->

        it "expands the contained link that matches the selector", ->
          $area = affix('div[up-expand=".second"]')
          $link1 = $area.affix('a.first[href="/path1"]')
          $link2 = $area.affix('a.second[href="/path2"]')
          up.hello($area)
          expect($area.attr('up-href')).toEqual('/path2')

        it 'does nothing if no contained link matches the selector', ->
          $area = affix('div[up-expand=".foo"]')
          $link = $area.affix('a[href="/path1"]')
          up.hello($area)
          expect($area.attr('up-href')).toBeUndefined()

        it 'does not match an element that is not a descendant', ->
          $area = affix('div[up-expand=".second"]')
          $link1 = $area.affix('a.first[href="/path1"]')
          $link2 = affix('a.second[href="/path2"]') # not a child of $area
          up.hello($area)
          expect($area.attr('up-href')).toBeUndefined()
