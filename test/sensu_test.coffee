chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
expect = chai.expect
nock = require 'nock'
nock.disableNetConnect()

#xmlHttpRequest = require 'xmlHttpRequest'
#xhr = require 'sinon/lib/sinon/util/fake_xml_http_request'


describe 'sensu', ->

#  xhr.create
#  server = sinon.fakeServer.create()

#  server.respondWith("GET", "/info",
#    [ 200,
#      {"Content-Type":"application/json"},
#      {"sensu":{"version":"0.12.0"},"rabbitmq":{"keepalives":{"messages":0,"consumers":1},"results":{"messages":0,"consumers":1},"connected":true},"redis":{"connected":true}}
#    ])

  beforeEach ->
    @server = nock('http://testhost')
                .get('/info')
                .reply(200, JSON.stringify({"sensu":{"version":"0.12.0"},"rabbitmq":{"keepalives":{"messages":0,"consumers":1},"results":{"messages":0,"consumers":1},"connected":true},"redis":{"connected":true}}), {"Content-Type":"application/json"})


#    @sandbox = sinon.sandbox.create()
#    @sandbox.useFakeServer()
#    fakeServer = require('sinon/lib/sinon/util/fake_server')
#    @server = fakeServer.create


    @robot =
      respond: sinon.spy()
      helpCommands: -> [ "hubot sensu client <client>", "something else" ]
#      brain:
#        data: {}
#        on: ->
#        emit: ->
    @msg =
      send: sinon.spy()
#      random: sinon.spy()

    require('../src/sensu.coffee')(@robot)

  describe 'general', ->
    it 'registers for sensu help', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu help/)

    it 'responds to sensu help', ->
      cb = @robot.respond.firstCall.args[1]
      cb(@msg)
      expect(@msg.send).to.have.been.calledWithMatch("hubot sensu client <client>")

    it 'registers for sensu info', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu info/)

    it 'responds to sensu info', ->
      cb = @robot.respond.firstCall.calledWith(/sensu info/)
#      cb = @robot.respond /sensu info/, @msg
      keys = (k for k, v of @robot.respond.firstCall when typeof v is 'function')
      console.log keys

#      cb = @robot.respond.invoke('sensu info')
#      cb = @robot.respond.calledWith('sensu info')
#      cb = @robot.respond.firstCall.args[1]
      cb(@msg)
#      @server.respond
#      expect(@msg.send).to.have.been.calledWithMatch(/Sensu version: 0.12.0\\nRabbitMQ: true, redis: true\\nRabbitMQ keepalives (messages\/consumers): (0\/1)\\nRabbitMQ results (messages\/consumers): (0\/1)/)
      expect(@msg.send).to.have.been.calledWithMatch("Sensu version: 0.12.0")
#      expect(@msg.send).to.have.been.calledWithMatch



#  respond: (regex, callback) ->
#    re = regex.toString().split('/')
#    re.shift()
#    modifiers = re.pop()
#
#    pattern = re.join('/')
#    name = @name.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
#
#    if @alias
#      alias = @alias.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
#      newRegex = new RegExp(
#        "^[@]?(?:#{alias}[:,]?|#{name}[:,]?)\\s*(?:#{pattern})"
#        modifiers
#      )
#    else
#      newRegex = new RegExp(
#        "^[@]?#{name}[:,]?\\s*(?:#{pattern})",
#        modifiers
#      )
#
#    @listeners.push new TextListener(@, newRegex, callback)














#    msg.http(config.sensu_api + '/info')
#      .get() (err, res, body) ->
#        if err
#          msg.send "Sensu says: #{err}"
#          return
#        if res.statusCode is 200
#          result = JSON.parse(body)
#          message = "Sensu version: #{result['sensu']['version']}"
#          message = message + '\nRabbitMQ: ' + result['rabbitmq']['connected'] + ', redis: ' + result['redis']['connected']
#          message = message + '\nRabbitMQ keepalives (messages/consumers): (' + result['rabbitmq']['keepalives']['messages'] + '/' + result['rabbitmq']['keepalives']['consumers'] + ')'
#          message = message + '\nRabbitMQ results (messages/consumers):' + result['rabbitmq']['results']['messages'] + '/' + result['rabbitmq']['results']['consumers'] + ')'
#          msg.send message
#        else
#          msg.send "An error occurred retrieving sensu info (#{res.statusCode}: #{body})"






  describe 'stashes', ->
    it 'responds to sensu stashes', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu stashes/)

    it 'responds to stashes', ->
      expect(@robot.respond).to.have.been.calledWith(/stashes/)

    it 'responds to sensu silence <alert>', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu silence test/)

    it 'responds to sensu silence <alert> for 2h', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu silence test for 2h/)

    it 'responds to silence <alert>', ->
      expect(@robot.respond).to.have.been.calledWith(/silence test/)

    it 'responds to sensu remove <stash>', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu remove stash/)

    it 'responds to remove stash', ->
      expect(@robot.respond).to.have.been.calledWith(/remove stash/)

  describe 'clients', ->
    it 'responds to sensu clients', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu clients/)

    it 'responds to sensu client <name> history', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu client blah history/)

    it 'responds to sensu client <name>', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu client blah/)

    it 'responds to sensu remove client <name>', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu remove client blah/)

    it 'responds to remove client <name>', ->
      expect(@robot.respond).to.have.been.calledWith(/remove client blah/)

  describe 'events', ->
    it 'responds to sensu events', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu events/)

    it 'responds to sensu events for <name>', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu events for blah/)

    it 'responds to sensu resolve event <event>', ->
      expect(@robot.respond).to.have.been.calledWith(/sensu resolve event blah\/blah2/)

    it 'responds to resolve event <event>', ->
      expect(@robot.respond).to.have.been.calledWith(/resolve event blah\/blah2/)
