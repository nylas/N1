_ = require 'underscore'
crypto = require 'crypto'
DOMUtils = require '../dom-utils'

class QuotedHTMLParser

  annotationClass: "nylas-quoted-text-segment"

  # Given an html string, it will add the `annotationClass` to the DOM
  # element
  hideQuotedHTML: (html, {keepIfWholeBodyIsQuote}={}) ->
    doc = @_parseHTML(html)
    quoteElements = @_findQuoteLikeElements(doc)
    if keepIfWholeBodyIsQuote and @_wholeBodyIsQuote(doc, quoteElements)
      return doc.children[0].innerHTML
    else
      @_annotateElements(quoteElements)
      return doc.children[0].innerHTML

  hasQuotedHTML: (html) ->
    doc = @_parseHTML(html)
    quoteElements = @_findQuoteLikeElements(doc)
    return quoteElements.length > 0

  # Public: Removes quoted text from an HTML string
  #
  # If we find a quoted text region that is "inline" with the root level
  # message, meaning it has non quoted text before and after it, then we
  # leave it in the message. If you set the `includeInline` option to true,
  # then all inline blocks will also be removed.
  #
  # - `html` The string full of quoted text areas
  # - `options`
  #   - `includeInline` Defaults false. If true, inline quotes are removed
  #   too
  #   - `keepIfWholeBodyIsQuote` Defaults false. If true, then it will
  #   check to see if the whole html body is a giant quote. If so, it will
  #   preserve it.
  #
  # Returns HTML without quoted text
  removeQuotedHTML: (html, options={}) ->
    doc = @_parseHTML(html)
    quoteElements = @_findQuoteLikeElements(doc, options)
    if options.keepIfWholeBodyIsQuote and @_wholeBodyIsQuote(doc, quoteElements)
      return doc.children[0].innerHTML
    else
      DOMUtils.removeElements(quoteElements, options)
      childNodes = doc.body.childNodes

      extraTailBrTags = []
      for i in [(childNodes.length - 1)..0] by -1
        curr = childNodes[i]
        next = childNodes[i - 1]
        if curr and curr.nodeName == 'BR' and next and next.nodeName == 'BR'
          extraTailBrTags.push(curr)
        else
          break

      DOMUtils.removeElements(extraTailBrTags)
      return doc.children[0].innerHTML

  appendQuotedHTML: (htmlWithoutQuotes, originalHTML) ->
    doc = @_parseHTML(originalHTML)
    quoteElements = @_findQuoteLikeElements(doc)
    doc = @_parseHTML(htmlWithoutQuotes)
    doc.body.appendChild(node) for node in quoteElements
    return doc.children[0].innerHTML

  restoreAnnotatedHTML: (html) ->
    doc = @_parseHTML(html)
    quoteElements = @_findAnnotatedElements(doc)
    @_removeAnnotation(quoteElements)
    return doc.children[0].innerHTML

  _parseHTML: (text) ->
    domParser = new DOMParser()
    try
      doc = domParser.parseFromString(text, "text/html")
    catch error
      text = "HTML Parser Error: #{error.toString()}"
      doc = domParser.parseFromString(text, "text/html")
      atom.emitError(error)
    return doc

  _wholeBodyIsQuote: (doc, quoteElements) ->
    nonBlankChildElements = []
    for child in doc.body.childNodes
      if child.textContent.trim() is ""
        continue
      else nonBlankChildElements.push(child)

    if nonBlankChildElements.length is 1
      return nonBlankChildElements[0] in quoteElements
    else return false

    # We used to have a scheme where we cached the `doc` object, keyed by
    # the md5 of the text. Unfortunately we can't do this because the
    # `doc` is mutated in place. Returning clones of the DOM is just as
    # bad as re-parsing from string, which is very fast anyway.

  _findQuoteLikeElements: (doc, {includeInline}={}) ->
    parsers = [
      @_findGmailQuotes
      @_findOffice365Quotes
      @_findBlockquoteQuotes
    ]

    quoteElements = []
    for parser in parsers
      quoteElements = quoteElements.concat(parser(doc) ? [])

    if not includeInline and quoteElements.length > 0
      # This means we only want to remove quoted text that shows up at the
      # end of a message. If there were non quoted content after, it'd be
      # inline.

      # We first need to find the common ancestor of the quoteElements.
      # This tells us what depth to look at to determine if there's real
      # content after us.
      ancestor = DOMUtils.commonAncestor(quoteElements)

      trailingQuotes = @_findTrailingQuotes(ancestor, quoteElements)

      # Only keep the trailing quotes so we can delete them.
      quoteElements = _.intersection(quoteElements, trailingQuotes)

    return _.compact(_.uniq(quoteElements))

  # This will recursievly move through the DOM, bottom to top, and pick
  # out quoted text blocks. It will stop when it reaches a visible
  # non-quote text region.
  _findTrailingQuotes: (scopeElement, quoteElements=[]) ->
    trailingQuotes = []

    # We need to find only the child nodes that have content in them. We
    # determine if it's an inline quote based on if there's VISIBLE
    # content after a piece of quoted text
    nodesWithContent = DOMUtils.nodesWithContent(scopeElement)

    # There may be multiple quote blocks that are sibilings of each
    # other at the end of the message. We want to include all of these
    # trailing quote elements.
    for nodeWithContent in nodesWithContent by -1
      if nodeWithContent in quoteElements
        # This is a valid quote. Let's keep it!
        #
        # This quote block may have many more quote blocks inside of it.
        # Luckily we don't need to explicitly find all of those because
        # one this block gets removed from the DOM, we'll delete all
        # sub-quotes as well.
        trailingQuotes.push(nodeWithContent)
        continue
      else
        moreTrailing = @_findTrailingQuotes(nodeWithContent, quoteElements)
        trailingQuotes = trailingQuotes.concat(moreTrailing)
        break

    return trailingQuotes

  _contains: (node, quoteElement) ->
    node is quoteElement or node.contains(quoteElement)

  _findAnnotatedElements: (doc) ->
    Array::slice.call(doc.getElementsByClassName(@annotationClass))

  _annotateElements: (elements=[]) ->
    for el in elements
      el.classList.add(@annotationClass)
      originalDisplay = el.style.display
      el.style.display = "none"
      el.setAttribute("data-nylas-quoted-text-original-display", originalDisplay)

  _removeAnnotation: (elements=[]) ->
    for el in elements
      el.classList.remove(@annotationClass)
      originalDisplay = el.getAttribute("data-nylas-quoted-text-original-display")
      el.style.display = originalDisplay
      el.removeAttribute("data-nylas-quoted-text-original-display")

  _findGmailQuotes: (doc) ->
    # There can sometimes be `div.gmail_quote` that are false positives.
    return Array::slice.call(doc.querySelectorAll('blockquote.gmail_quote'))

  _findOffice365Quotes: (doc) ->
    elements = doc.querySelectorAll('#divRplyFwdMsg, #OLK_SRC_BODY_SECTION')
    elements = Array::slice.call(elements)

    weirdEl = doc.getElementById('3D"divRplyFwdMsg"')
    if weirdEl then elements.push(weirdEl)

    elements = _.map elements, (el) ->
      if el.previousElementSibling and el.previousElementSibling.nodeName is "HR"
        return el.parentElement
      else return el
    return elements

  _findBlockquoteQuotes: (doc) ->
    return Array::slice.call(doc.querySelectorAll('blockquote'))


module.exports = new QuotedHTMLParser
