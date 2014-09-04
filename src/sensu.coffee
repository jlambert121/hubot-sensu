# Description:
#   Sensu API hubot client
#
# Dependencies:
#   "moment": ">=1.6.0"
#
# Configuration:
#   HUBOT_SENSU_API_UR - URL for the sensu api service.  http://sensu.yourdomain.com:4567
#   HUBOT_SENSU_DOMAIN - Domain to force on all clients.  Not used if blank/unset
#
# Commands:
#   hubot sensu info - show sensu api info
#   hubot sensu stashes - show contents of the sensu stash
#   hubot sensu silence <client>[/service] [for \d+[unit]] - silence an alert for an optional period of time (default 1h)
#   hubot sensu remove stash <stash> - remove a stash from sensu
#   hubot sensu clients - show all clients
#   hubot sensu client <client>[ history] - show a specific client['s history]
#   hubot sensu sensu remove client <client> - remove a client from sensu
#   hubot sensu events[ for <client>] - show all events or for a specific client
#   hubot sensu resolve event <client>/<service> - resolve a sensu event
#
# Notes:
#   Requires Sensu >= 0.12 because of expire parameter on stashes and updated /resolve and /request endpoints
#   Checks endpoint not implemented (http://docs.sensuapp.org/0.12/api/checks.html) -- also note /check/request is deprecated in favor of /request
#   Aggregates endpoint not implemented (http://docs.sensuapp.org/0.12/api/aggregates.html)
#
# Author:
#   Justin Lambert - jlambert121
#

config =
  sensu_api: process.env.HUBOT_SENSU_API_URL

moment = require('moment')

module.exports = (robot) ->

  validateVars = () ->
    unless config.sensu_api
      robot.logger.error "HUBOT_SENSU_API_URL is unset"
      msg.send "Please set the HUBOT_SENSU_API_URL environment variable."
      return

######################
#### Info methods ####
######################
  robot.respond /sensu help/i, (msg) ->
    cmds = robot.helpCommands()
    cmds = (cmd for cmd in cmds when cmd.match(/(sensu)/))
    msg.send cmds.join("\n")

  robot.respond /sensu info/i, (msg) ->
    validateVars
    robot.http(config.sensu_api + '/info')
      .get() (err, res, body) ->
        if err
          msg.send "Sensu says: #{err}"
          return
        if res.statusCode is 200
          result = JSON.parse(body)
          message = "Sensu version: #{result['sensu']['version']}"
          message = message + '\nRabbitMQ: ' + result['transport']['connected'] + ', redis: ' + result['redis']['connected']
          message = message + '\nRabbitMQ keepalives (messages/consumers): (' + result['transport']['keepalives']['messages'] + '/' + result['transport']['keepalives']['consumers'] + ')'
          message = message + '\nRabbitMQ results (messages/consumers):' + result['transport']['results']['messages'] + '/' + result['transport']['results']['consumers'] + ')'
          msg.send message
        else
          msg.send "An error occurred retrieving sensu info (#{res.statusCode}: #{body})"


#######################
#### Stash methods ####
#######################
  robot.respond /(?:sensu)? stashes/i, (msg) ->
    validateVars
    robot.http(config.sensu_api + '/stashes')
      .get() (err, res, body) ->
        if err
          msg.send "Sensu says: #{err}"
          return
        results = JSON.parse(body)
        output = []
        for result,value of results
          console.log value
          message = value['path'] + ' added on ' + moment.unix(value['content']['timestamp']).format('HH:MM M/D/YY')
          if value['content']['by']
            message = message + ' by ' + value['content']['by']
          if value['expire'] and value['expire'] > 0
            message = message + ', expires in ' + value['expire'] + ' seconds'
          output.push message
        msg.send output.sort().join('\n')

  robot.respond /(?:sensu)? silence ([^\s\/]*)(?:\/)?([^\s]*)?(?: for (\d+)(\w))?/i, (msg) ->
    # msg.match[1] = client
    # msg.match[2] = event (optional)
    # msg.match[3] = duration (optional)
    # msg.match[4] = units (required if duration)

    validateVars
    client = addClientDomain(msg.match[1])

    if msg.match[2]
      path = client + '/' + msg.match[2]
    else
      path = client

    duration = msg.match[3]
    if msg.match[4]
      unit = msg.match[4]
      switch unit
        when 's'
          expiration = duration * 1
        when 'm'
          expiration = duration * 60

        when 'h'
          expiration = duration * 3600
        when 'd'
          expiration = duration * 24 * 3600
        else
          msg.send 'Unknown duration (' + unit + ').  I know s (seconds), m (minutes), h (hours), and d (days)'
          return
      human_d = duration + unit
    else
      expiration = 3600
      human_d = '1h'

    data = {}
    data['content'] = {}
    data['content']['timestamp'] = moment().unix()
    data['content']['by'] = msg.message.user.name
    data['expire'] = expiration
    data['path'] = 'silence/' + path

    robot.http(config.sensu_api + '/stashes')
      .post(JSON.stringify(data)) (err, res, body) ->
        if res.statusCode is 201
          msg.send path + ' silenced for ' + human_d
        else if res.statusCode is 400
          msg.send 'API returned malformed error for path silence/' + path + '\ndata: ' + JSON.stringify(data)
        else
          msg.send "API returned an error for path silence/#{path}\ndata: #{JSON.stringify(data)}\nresponse:#{res.statusCode}: #{body}"

  robot.respond /(?:sensu)? remove stash (.*)/i, (msg) ->
    validateVars

    stash = msg.match[1]
    unless stash.match /^silence\//
      stash = 'silence/' + stash

    # If it is only a hostname, verify domain name
    unless stash.match /^silence\/(.*)\//
      stash = addClientDomain(stash)

    robot.http(config.sensu_api + '/stashes/' + stash)
      .delete() (err, res, body) ->
        if err
          msg.send "Sensu says: #{err}"
          return
        if res.statusCode is 204
          msg.send stash + ' removed'
        else if res.statusCode is 404
          msg.send stash + ' not found'
        else
          msg.send "API returned an error removing #{stash} (#{res.statusCode}: #{body})"

########################
#### Client methods ####
########################
  robot.respond /sensu clients/i, (msg) ->
    validateVars
    robot.http(config.sensu_api + '/clients')
      .get() (err, res, body) ->
        if err
          msg.send "Sensu says: #{err}"
          return
        results = JSON.parse(body)
        output = []
        for result,value of results
          output.push value['name'] + ' (' + value['address'] + ') subscriptions: ' + value['subscriptions'].sort().join(', ')

        if output.length is 0
          msg.send 'No clients'
        else
          msg.send output.sort().join('\n')

  robot.respond /sensu client (.*)( history)/i, (msg) ->
    validateVars
    client = addClientDomain(msg.match[1])

    robot.http(config.sensu_api + '/clients/' + client + '/history')
      .get() (err, res, body) ->
        if err
          msg.send "Sensu says: #{err}"
          return
        if res.statusCode is 200
          results = JSON.parse(body)
          output = []
          for result,value of results
            output.push value['check'] + ' (last execution: ' + moment.unix(value['last_execution']).format('HH:MM M/D/YY') + ') history: ' + value['history'].join(', ')

          if output.length is 0
            msg.send 'No history found for ' + client
          else
            message = 'History for ' + client
            message = message + output.sort().join('\n')
            msg.send message
        else if res.statusCode is 404
          msg.send client + ' not found'
        else
          msg.send "An error occurred looking up #{client}'s history (#{res.statusCode}: #{body})"


  robot.respond /sensu client (.*)/i, (msg) ->
    validateVars
    client = addClientDomain(msg.match[1])

    robot.http(config.sensu_api + '/clients/' + client)
      .get() (err, res, body) ->
        if err
          msg.send "Sensu says: #{err}"
          return
        if res.statusCode is 200
          result = JSON.parse(body)
          msg.send result['name'] + ' (' + result['address'] + ') subscriptions: ' + result['subscriptions'].sort().join(', ')
        else if res.statusCode is 404
          msg.send client + ' not found'
        else
          msg.send "An error occurred looking up #{client} #{res.statusCode}: #{body}"


  robot.respond /(?:sensu)? remove client (.*)/i, (msg) ->
    validateVars
    client= addClientDomain(msg.match[1])

    robot.http(config.sensu_api + '/clients/' + client)
      .delete() (err, res, body) ->
        if err
          msg.send "Sensu says: #{err}"
          return
        if res.statusCode is 202
          msg.send client + ' removed'
        else if res.statusCode is 404
          msg.send client + ' not found'
        else
          msg.send "API returned an error removing #{client} (#{res.statusCode}: #{res.body})"

#######################
#### Event methods ####
#######################
  robot.respond /sensu events(?: for (.*))?/i, (msg) ->
    validateVars
    if msg.match[1]
      client = '/' + addClientDomain(msg.match[1])
    else
      client = ''

    robot.http(config.sensu_api + '/events' + client)
      .get() (err, res, body) ->
        if err
          msg.send "Sensu says: #{err}"
          return
        results = JSON.parse(body)
        output = []
        for result,value of results
          if value['flapping']
            flapping = ', flapping'
          else
            flapping = ''
          output.push value['client'] + ' (' + value['check'] + flapping + ') - ' + value['output']
        if output.length is 0
          message = 'No events'
          if client != ''
            message = message + ' for ' + msg.match[1]
          msg.send message
        msg.send output.sort().join('\n')

  robot.respond /(?:sensu)? resolve event (.*)(?:\/)(.*)/i, (msg) ->
    validateVars
    client = addClientDomain(msg.match[1])

    data = {}
    data['client'] = client
    data['check'] = msg.match[2]

    robot.http(config.sensu_api + '/resolve')
      .post(JSON.stringify(data)) (err, res, body) ->
        if err
          msg.send "Sensu says: #{err}"
          return
        if res.statusCode is 202
          msg.send 'Event resolved'
        else if res.statusCode is 404
          msg.send msg.match[1] + '/' + msg.match[2] + ' not found'
        else
          msg.send "API returned an error resolving #{msg.match[1]}/#{msg.match[2]} (#{res.statusCode}: #{res.body})"

addClientDomain = (client) ->
  if process.env.HUBOT_SENSU_DOMAIN != undefined
    domainMatch = new RegExp("\.#{process.env.HUBOT_SENSU_DOMAIN}$", 'i')
    unless domainMatch.test(client)
      client = client + '.' + process.env.HUBOT_SENSU_DOMAIN
  client
