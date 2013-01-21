command = {}

command.help =
  help: "help\t\t\t\tShow this help"
  run: (args) ->
    cmdhelp = (command[cmd].help for cmd of command).join('\n    ')
    help =
    """
    Usage: swot <command> [OPTIONS]
      Commands:

    """ + '    ' + cmdhelp + '\n'
    process.stdout.write help
