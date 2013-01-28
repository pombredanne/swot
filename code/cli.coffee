#!/usr/bin/env coffee

fs = require 'fs'
path = require 'path'
child_process = require 'child_process'

async = require 'async'
request = require 'request'

existsSync = fs.existsSync || path.existsSync

command = {}

command.help =
  help: "help\t\t\t\t\tShow this help"
  run: (args) ->
    cmdhelp = (command[cmd].help for cmd of command).join('\n    ')
    help =
    """
    Usage: swot <command> [OPTIONS]
      Commands:

    """ + '    ' + cmdhelp + '\n'
    process.stdout.write help

command.setup =
  help: "setup <boxname> <apikey> [boxserver]\tSet tool project"
  run: (args) ->
    boxName = args[2]
    apikey = args[3]
    boxServer = args[4] ? "https://box.scraperwiki.com"
    sshkey_pub_path = process.env.SSHKEY || "#{process.env.HOME}/.ssh/id_rsa.pub"
    # add ssh key
    uri = "#{boxServer}/#{boxName}/sshkeys"
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
        boxServer: boxServer
      filename = ".swotconfig"
      fs.writeFileSync filename, JSON.stringify(obj, null, 2)
      console.log "saved details in #{filename}"
      process.exit(0)

syncing = false
mustSync = false
patience = 1000 # time to wait until syncing, in milliseconds
forever = false

doSync = (cb) ->
  mustSync = forever  # normally forever is false
  {sshkey, boxName, toolName, boxServer} = JSON.parse(fs.readFileSync(".swotconfig"))
  toolName = toolName or 'tool'
  [t_, host] = boxServer.match /https?:\/\/(.+)/
  cmd = ['rsync', '-rlp', '-e', "ssh -o IdentitiesOnly=yes -i #{sshkey}", '.', "#{boxName}@#{host}:#{toolName}"]
  # enable for debug: console.log "running #{cmd.join ' '}"
  process.stdout.write "Syncing..."
  child = child_process.spawn cmd[0], cmd[1..]
  child.stdout.pipe process.stdout
  child.stderr.pipe process.stderr
  child.on 'error', ->
    console.warn "exec: #{error}"
  child.on 'exit', ->
    console.log '\rSynced!   '
    cb null

sync = ->
  """Sync using rsync to the remote box."""
  mustSync = true
  if syncing then return
  syncing = true
  async.whilst((-> mustSync), doSync,
    (-> syncing = false))

command.sync =
  help: "sync [--loop]\t\t\t\tSync once / or loop forever"
  run: (arg) ->
    if arg[2] == '--loop'
      forever = true
    sync (err) ->
      process.exit 0 unless err?
      process.exit err.code

# On OS X there is a bug in fs.watch that means that it doesn't work
# so well. See https://github.com/joyent/node/issues/3343 and others
# for more details. I think we expect this to be fixed in whatever
# stable Node version comes after 0.9.x.
command.watch =
  help: "watch\t\t\t\t\tWatch files and rsync on change. Not on OS X :-("
  run: (args) ->
    unless existsSync '.swotconfig'
      console.warn '.swotconfig not found, try running "swot help setup".'
      process.exit 16
    timer = setTimeout(sync, patience)
    fs.watch '.', (event, filename) ->
      clearTimeout(timer)
      timer = setTimeout(sync, patience)

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
