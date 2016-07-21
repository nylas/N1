proxyquire = require 'proxyquire'
React = require "react"
ReactDOM = require "react-dom"
ReactTestUtils = require('react-addons-test-utils')

{Contact,
 Message,
 File,
 FileDownloadStore,
 MessageBodyProcessor} = require "nylas-exports"

EmailFrameStub = React.createClass({render: -> <div></div>})

{InjectedComponent} = require 'nylas-component-kit'

file = new File
  id: 'file_1_id'
  filename: 'a.png'
  contentType: 'image/png'
  size: 10
file_not_downloaded = new File
  id: 'file_2_id'
  filename: 'b.png'
  contentType: 'image/png'
  size: 10
file_inline = new File
  id: 'file_inline_id'
  filename: 'c.png'
  contentId: 'file_inline_id'
  contentType: 'image/png'
  size: 10
file_inline_downloading = new File
  id: 'file_inline_downloading_id'
  filename: 'd.png'
  contentId: 'file_inline_downloading_id'
  contentType: 'image/png'
  size: 10
file_inline_not_downloaded = new File
  id: 'file_inline_not_downloaded_id'
  filename: 'e.png'
  contentId: 'file_inline_not_downloaded_id'
  contentType: 'image/png'
  size: 10
file_cid_but_not_referenced = new File
  id: 'file_cid_but_not_referenced'
  filename: 'f.png'
  contentId: 'file_cid_but_not_referenced'
  contentType: 'image/png'
  size: 10
file_cid_but_not_referenced_or_image = new File
  id: 'file_cid_but_not_referenced_or_image'
  filename: 'ansible notes.txt'
  contentId: 'file_cid_but_not_referenced_or_image'
  contentType: 'text/plain'
  size: 300
file_without_filename = new File
  id: 'file_without_filename'
  contentType: 'image/png'
  size: 10

download =
  fileId: 'file_1_id'
download_inline =
  fileId: 'file_inline_downloading_id'

user_1 = new Contact
  name: "User One"
  email: "user1@nylas.com"
user_2 = new Contact
  name: "User Two"
  email: "user2@nylas.com"
user_3 = new Contact
  name: "User Three"
  email: "user3@nylas.com"
user_4 = new Contact
  name: "User Four"
  email: "user4@nylas.com"

MessageItemBody = proxyquire '../lib/message-item-body',
  './email-frame': {default: EmailFrameStub}


describe "MessageItem", ->
  beforeEach ->
    spyOn(FileDownloadStore, 'pathForFile').andCallFake (f) ->
      return '/fake/path.png' if f.id is file.id
      return '/fake/path-inline.png' if f.id is file_inline.id
      return '/fake/path-downloading.png' if f.id is file_inline_downloading.id
      return null
    spyOn(MessageBodyProcessor, '_addToCache').andCallFake ->

    @downloads =
      'file_1_id': download,
      'file_inline_downloading_id': download_inline

    @message = new Message
      id: "111"
      from: [user_1]
      to: [user_2]
      cc: [user_3, user_4]
      bcc: null
      body: "Body One"
      date: new Date(1415814587)
      draft: false
      files: []
      unread: false
      snippet: "snippet one..."
      subject: "Subject One"
      threadId: "thread_12345"
      accountId: window.TEST_ACCOUNT_ID

    # Generate the test component. Should be called after @message is configured
    # for the test, since MessageItem assumes attributes of the message will not
    # change after getInitialState runs.
    @createComponent = ({collapsed} = {}) =>
      collapsed ?= false
      @component = ReactTestUtils.renderIntoDocument(
        <MessageItemBody message={@message} downloads={@downloads} />
      )
      advanceClock()

  describe "when the message contains attachments", ->
    beforeEach ->
      @message.files = [
        file,
        file_not_downloaded,
        file_cid_but_not_referenced,
        file_cid_but_not_referenced_or_image,

        file_inline,
        file_inline_downloading,
        file_inline_not_downloaded,
        file_without_filename
      ]

    describe "inline", ->
      beforeEach ->
        @message.body = """
          <img alt=\"A\" src=\"cid:#{file_inline.contentId}\"/>
          <img alt=\"B\" src=\"cid:#{file_inline_downloading.contentId}\"/>
          <img alt=\"C\" src=\"cid:#{file_inline_not_downloaded.contentId}\"/>
          <img src=\"cid:missing-attachment\"/>
          """
        @createComponent()

      it "should never leave src=cid:// in the message body", ->
        body = ReactTestUtils.findRenderedComponentWithType(@component, EmailFrameStub).props.content
        expect(body.indexOf('cid')).toEqual(-1)

      it "should replace cid://<file.contentId> with the FileDownloadStore's path for the file", ->
        body = ReactTestUtils.findRenderedComponentWithType(@component, EmailFrameStub).props.content
        expect(body.indexOf('alt="A" src="file:///fake/path-inline.png"')).toEqual(@message.body.indexOf('alt="A"'))

      it "should not replace cid://<file.contentId> with the FileDownloadStore's path if the download is in progress", ->
        body = ReactTestUtils.findRenderedComponentWithType(@component, EmailFrameStub).props.content
        expect(body.indexOf('/fake/path-downloading.png')).toEqual(-1)

  describe "showQuotedText", ->
    it "should be initialized to false", ->
      @createComponent()
      expect(@component.state.showQuotedText).toBe(false)

    it "shouldn't render the quoted text control if there's no quoted text", ->
      @message.body = "no quotes here!"
      @createComponent()
      toggles = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, 'quoted-text-control')
      expect(toggles.length).toBe 0

    describe 'quoted text control toggle button', ->
      beforeEach ->
        @message.body = """
          Message
          <blockquote class="gmail_quote">
            Quoted message
          </blockquote>
          """
        @createComponent()
        @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@component, 'quoted-text-control')

      it 'should be rendered', ->
        expect(@toggle).toBeDefined()

    it "should be initialized to true if the message contains `Forwarded`...", ->
      @message.body = """
        Hi guys, take a look at this. Very relevant. -mg
        <br>
        <br>
        <div class="gmail_quote">
          ---- Forwarded Message -----
          blablalba
        </div>
        """
      @createComponent()
      expect(@component.state.showQuotedText).toBe(true)

    it "should be initialized to false if the message is a response to a Forwarded message", ->
      @message.body = """
        Thanks mg, that indeed looks very relevant. Will bring it up
        with the rest of the team.

        On Sunday, March 4th at 12:32AM, Michael Grinich Wrote:
        <div class="gmail_quote">
          Hi guys, take a look at this. Very relevant. -mg
          <br>
          <br>
          <div class="gmail_quote">
            ---- Forwarded Message -----
            blablalba
          </div>
        </div>
        """
      @createComponent()
      expect(@component.state.showQuotedText).toBe(false)

    describe "when showQuotedText is true", ->
      beforeEach ->
        @message.body = """
          Message
          <blockquote class="gmail_quote">
            Quoted message
          </blockquote>
          """
        @createComponent()
        @component.setState(showQuotedText: true)

      describe 'quoted text control toggle button', ->
        beforeEach ->
          @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@component, 'quoted-text-control')

        it 'should be rendered', ->
          expect(@toggle).toBeDefined()

      it "should pass the value into the EmailFrame", ->
        frame = ReactTestUtils.findRenderedComponentWithType(@component, EmailFrameStub)
        expect(frame.props.showQuotedText).toBe(true)
