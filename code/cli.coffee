#!/usr/bin/env coffee

request = require 'request'
fs = require 'fs'

URLBASE = 'https://box.scraperwiki.com'

command = {}

command.help =
  help: "help\tShow this help"
  run: (args) ->
    cmdhelp = (command[cmd].help for cmd of command).join('\n    ')
    help =
    """
    Usage: swot <command> [OPTIONS]
      Commands:

    """ + '    ' + cmdhelp + '\n'
    process.stdout.write help

command.setup =
  help: "setup <boxname> <apikey>\tSet tool project"
  run: (args) ->
    console.log args
    boxName = args[2]
    apikey = args[3]
    sshkey_pub_path = process.env.SSHKEY || "#{process.env.HOME}/.ssh/id_rsa.pub"
    # add ssh key
    uri = "#{URLBASE}/#{boxName}/sshkeys"
    options =
      uri: uri
      form:
        apikey: apikey
        sshkey: fs.readFileSync sshkey_pub_path, "ascii"
    request.post options, (err, resp, body) ->
      if err
        console.warn "Error connecting to #{uri}: #{err}"
        process.exit (4)
      if ! /^2/.test(resp.statusCode)
        console.warn "Status code error from #{uri}: #{resp.statusCode} #{body}"
        process.exit (8)
      # ssh key now added
      obj =
        boxName: boxName
        apikey: apikey
      filename = ".swotconfig"
      fs.writeFileSync filename, JSON.stringify(obj)
      console.log "saved details in #{filename}"
      process.exit(0)

command.watch =
  help: "watch\tWatch files and rsync on change"
  run: (args) ->
    # check for .swotconfig, exit if it doesn't exist
    # Watch current dir for changes (limit to one event per n seconds)
    # rsync over ssh on change

exports.main = main = (args) ->
  # If supplied *args* should be a list of arguments,
  # including args[0], the command name; if not supplied,
  # process.argv will be used.
  if not args?
    args = process.argv[1..]

  cmd_name = args[1]
  if cmd_name of command
    command[cmd_name].run(args)
  else if not cmd_name?
    command['help'].run(args)
  else
    process.stderr.write("I don't understand '#{args[1]}', try swot help\n")

if require.main is module
  main()
