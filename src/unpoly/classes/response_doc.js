const u = up.util
const e = up.element

up.ResponseDoc = class ResponseDoc {

  constructor({ document, fragment, content, target, origin, cspNonces, match }) {
    if (document) {
      this._parseDocument(document)
    } else if (fragment) {
      this._parseFragment(fragment)
    } else {
      // Parsing { inner } is the last option we try. It should always succeed in case someone
      // tries `up.layer.open()` without any args. Hence we default the innerHTML to an empty string.
      this._parseContent(content || '', target)
    }

    // If the user doesn't want to run scripts in the new fragment, we disable all <script> elements.
    if (!up.fragment.config.runScripts) {
      this._pluckElement.querySelectorAll('script').forEach((e) => e.remove())
    }

    this._cspNonces = cspNonces

    if (origin) {
      let originSelector = up.fragment.tryToTarget(origin)
      if (originSelector) {
        this._rediscoveredOrigin = this.select(originSelector)
      }
    }

    this._match = match
  }

  _parseDocument(document) {
    document = this._parse(document, e.createDocumentFromHTML)
    this._useParseResult(document)
  }

  _parseFragment(fragment) {
    fragment = this._parse(fragment, e.createFromHTML)
    this._useParseResult(fragment)
  }

  _parseContent(content, target) {
    if(!target) up.fail("must pass a { target } when passing { content }")

    target = u.map(up.fragment.parseTargetSteps(target), 'selector').join()

    // Conjure an element that will later match target in @select()
    const matchingElement = e.createFromSelector(target)

    if (u.isString(content)) {
      // Don't use e.createFromHTML() here, since content may be a text node.
      matchingElement.innerHTML = content
    } else {
      matchingElement.appendChild(content)
    }

    this._useParseResult(matchingElement)
  }

  _parse(value, parseFn) {
    if (u.isString(value)) {
      value = parseFn(value)
    }
    return value
  }

  _useParseResult(node) {
    this._rootElement = node

    if (node instanceof HTMLHtmlElement) {
      this._pluckElement = node
    } else {
      // We're creating a faux document to append our fragment root to.
      // This way, when a step selects the fragment root it will no longer be available
      // for selection by a later step.
      this._pluckElement = document.createElement('up-document')
      this._pluckElement.append(node)
    }
  }

  rootSelector() {
    return up.fragment.toTarget(this._rootElement)
  }

  get title() {
    // We retrieve the title by looking up the <head> element explicitly.
    // We want to distinguish between a parsed document that does not have a <head> or <title>
    // and a given, but empty title.
    return this._fromHead(this._getTitleText)
  }

  /*
  Returns the root's `<head>`, if it has one.

  Returns `undefined` if the root has no contentful `<head>`, e.g. if the root was
  parsed from a fragment, or from a docuemnt without a `<head>` element.
  */
  // eslint-disable-next-line getter-return
  _getHead() {
    // The root may be a `Document` (which always has a `#head`, even if it wasn't present in the HTML)
    // or an `Element` (which never has a `#head`).
    let head = this._pluckElement.querySelector('head')

    // DocumentParser also produces a document with a <head>, even if the initial HTML
    // has no <head> element. To work around this we consider the head to be missing
    // if it has no child nodes.
    if (head && head.childNodes.length > 0) {
      return head
    }
  }

  _fromHead(fn) {
    let head = this._getHead()
    return head && fn(head)
  }

  get metaTags() {
    return this._fromHead(up.history.findMetaTags)
  }

  get assets() {
    return this._fromHead(up.script.findAssets)
  }

  _getTitleText(head) {
    // We must find inside the head ('head title') instead of 'title'
    // so we won't match the <title> of an inline SVG image.
    return head.querySelector('title')?.textContent
  }

  // (1) Selects a single fragment with the given selector.
  // (2) Supports custom Unpoly selectors like :has() or :main.
  // (3) Supports origin-aware lookup priorities.
  // (4) Returns undefined if there is no match.
  select(selector) {
    let finder = new up.FragmentFinder({
      selector: selector,
      origin: this._rediscoveredOrigin,
      document: this._pluckElement,
      match: this._match,
    })
    return finder.find()
  }

  selectSteps(steps) {
    return steps.filter((step) => {
      return this._trySelectStep(step) || this._cannotMatchStep(step)
    })
  }

  commitSteps(steps) {
    return steps.filter((step) => {
      // If multiple steps want to match the same new element, the first step will remain in the left.
      // This will happen when multiple layers have the same hungry element with [up-if-layer=any].
      if (this._pluckElement.contains(step.newElement)) {
        step.newElement.remove()
        return true
      }
    })
  }

  _trySelectStep(step) {
    if (step.newElement) {
      return true
    }

    // Look for a match in the new content.
    // The new content has no layers, so no { layer } option here.
    let newElement = this.select(step.selector)

    if (!newElement) {
      return
    }

    let { selectEvent } = step
    if (selectEvent) {
      selectEvent.newFragment = newElement
      selectEvent.renderOptions = step.originalRenderOptions
      up.emit(step.oldElement, selectEvent, { callback: step.selectCallback })
      if (selectEvent.defaultPrevented) {
        return
      }
    }

    step.newElement = newElement
    return true
  }

  _cannotMatchStep(step) {
    if (!step.maybe) {
      // An error message will be chosen by up.Change.FromContent
      throw new up.CannotMatch()
    }
  }

  finalizeElement(element) {
    // Rewrite per-request CSP nonces to match that of the current page.
    up.NonceableCallback.adoptNonces(element, this._cspNonces)
  }

  static {
    // Cache since multiple plans will query this.
    u.memoizeMethod(this.prototype, {
      _getHead: true,
    })
  }

}
