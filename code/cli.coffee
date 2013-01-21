#!/usr/bin/env coffee
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
    # add ssh key
    # save boxName & apikey into .swotconfig

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
