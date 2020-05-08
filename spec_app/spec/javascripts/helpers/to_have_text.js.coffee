u = up.util
$ = jQuery

beforeEach ->
  jasmine.addMatchers
    toHaveText: (util, customEqualityTesters) ->
      compare: (element, expectedText) ->
        element = up.fragment.first(element)
        actualText = element?.textContent?.trim()

        result = {}
        result.pass = !!element

        if u.isString(expectedText)
          expectedText = expectedText.trim()
          result.pass &&= (actualText == expectedText)
        else if u.isRegExp(expectedText)
          result.pass &&= (expectedText.test(actualText))

        if result.pass
          result.message = u.sprintf('Expected element %o to not have text %s', element, actualText)
        else
          result.message = u.sprintf('Expected element %o to have text %s, but its text was %s', element, expectedText, actualText)

        return result

