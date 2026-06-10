
ShellTesting
============

The ShellTesting package provides support for writing tests for command-line tools.  The expectation is that the tools need to be spawned, environment variables set, standard input fed, and standard output or standard error captured and compared to the expected output.

The motivation for this package was to convert the shell-script tests in the various repositories for POSIX command line tools used in Darwin.

Much of the needed functionality was implemented in the dependency package CMigration which is  used to implement these command line tools.

