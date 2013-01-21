#!/usr/bin/env coffee

fs = require 'fs'
path = require 'path'
child_process = require 'child_process'

async = require 'async'
request = require 'request'

existsSync = fs.existsSync || path.existsSync

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
        sshkey: sshkey_pub_path.replace('.pub', '') # todo: use RE
      filename = ".swotconfig"
      fs.writeFileSync filename, JSON.stringify(obj)
      console.log "saved details in #{filename}"
      process.exit(0)

lastSync = null
syncing = false
mustSync = false

doSync = (cb) ->
  mustSync = false
  {sshkey, boxName} = JSON.parse(fs.readFileSync(".swotconfig"))
  toolname = path.basename(process.cwd())
  cmd = ['rsync', '-rlpE', '-e', "ssh -i #{sshkey}", '.', "#{boxName}@box.scraperwiki.com:#{toolname}"]
  console.log "running #{cmd.join ' '}"
  child = child_process.spawn cmd[0], cmd[1..]
  child.stdout.pipe process.stdout
  child.stderr.pipe process.stderr
  child.on 'error', ->
    console.warn "exec: #{error}"
  child.on 'exit', ->
    cb null

sync = ->
  """Sync using rsync to the remote box."""
  syncing = true
  mustSync = true
  async.whilst((-> mustSync), doSync,
    (-> lastSync = new Date(); syncing = false))

command.watch =
  help: "watch\tWatch files and rsync on change"
  run: (args) ->
    unless existsSync '.swotconfig'
      console.warn '.swotconfig not found, try running "swot help setup".'
      process.exit 16
    fs.watch '.', (event, filename) ->
      SYNCDELAY = 1000
      # Limit so that we sync at most once every SYNCDELAY milliseconds.
      now = new Date()
      # If syncing is true, then we neeed to sync again immediately after we finish.
      if syncing
        mustSync = true
        return
      if lastSync
        # answer in milliseconds.
        age = now - lastSync
      else
        age = 1e6
      if age > SYNCDELAY
        sync()


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
