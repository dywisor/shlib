#!/usr/bin/python3
# -*- coding: utf-8 -*-
# Copyright (C) 2013 André Erdmann <dywi@mailerd.de>
# Distributed under the terms of the GNU General Public License;
# either version 2 of the License, or (at your option) any later version.
#
# script for creating and building shlib recipes
#
# Note that this script doesn't work with python 2.
#

import argparse
import os
import subprocess
import sys
import time

def quote_str ( s ):
   return "\"" + str ( s ) + "\""
# --- end of quote_str (...) ---

def die ( message=None, code=None ):
   if message is not None:
      sys.stderr.write ( str ( message ).rstrip() + "\n" )

   sys.exit ( ( 1 ^ os.EX_OK ) if code is None else code )
# --- end of die (...) ---

def run_command_v (
   cmdv, *,
   env=None, env_extend=None, return_success=True, stdout=None, stderr=None
):
   if env_extend:
      my_env = dict ( os.environ if env is None else env )
      my_env.update ( env_extend )
   else:
      my_env = os.environ if env is None else env


   cmd_call = None

   try:
      cmd_call = subprocess.Popen (
         cmdv, stdin=None, stdout=stdout, stderr=stderr, env=my_env
      )
      output = cmd_call.communicate()
   except:
      if cmd_call is not None:
         try:
            cmd_call.terminate()
            time.sleep ( 1 )
         finally:
            cmd_call.kill()
      raise
   # -- end try

   if return_success:
      return cmd_call.returncode
   else:
      return ( cmd_call, output )
# --- end of run_command_v (...) ---

def run_command ( *cmdv, **kwargs ):
   return run_command_v ( cmdv, **kwargs )
# --- end of run_command (...) ---

def autodie_command ( *cmdv, env=None, env_extend=None ):
   retcode = run_command_v (
      cmdv, return_success=True, env=env, env_extend=env_extend
   )
   if retcode != os.EX_OK:
      die (
         "command {!r} returned {}".format ( ' '.join ( cmdv ), retcode )
      )
# --- end of autodie_command (...) ---

def get_argument_parser():

   def create_fs_acceptor (
      fspath_acceptor, value_acceptor=None, value_acceptor_xform=None,
      name=None, doc=None
   ):
      def wrapped_acceptor ( value ):
         f = os.path.abspath ( os.path.expanduser ( value ) )
         if fspath_acceptor ( f ):
            return f
         else:
            raise argparse.ArgumentTypeError ( value )
      # --- end of wrapped_acceptor (...) ---

      def wrapped_acceptor_precondition ( value ):
         if value_acceptor ( value ):
            if value_acceptor_xform is None:
               return value
            else:
               return value_acceptor_xform ( value )
         else:
            f = os.path.abspath ( os.path.expanduser ( value ) )
            if fspath_acceptor ( f ):
               return f
            else:
               raise argparse.ArgumentTypeError ( value )
      # --- end of wrapped_acceptor_precondition (...) ---

      if value_acceptor is None:
         retfunc = wrapped_acceptor
      else:
         retfunc = wrapped_acceptor_precondition

      if name is not None:
         retfunc.__name__ = name

      if doc is not None:
         retfunc.__doc__ = doc

      return retfunc
   # --- end of create_fs_acceptor (...) ---


   is_fs_dir       = create_fs_acceptor ( os.path.isdir )
   couldbe_fs_dir  = create_fs_acceptor (
      lambda k: ( ( not os.path.exists ( k ) ) or os.path.isdir ( k ) )
   )
   is_fs_file      = create_fs_acceptor ( os.path.isfile )
   couldbe_fs_file = create_fs_acceptor (
      lambda k: ( ( not os.path.exists ( k ) ) or os.path.isfile ( k ) )
   )

   UNSET = argparse.SUPPRESS


   parser = argparse.ArgumentParser (
      description="shlib script/lib generator",
   )
   arg = parser.add_argument

   builddirs_group = parser.add_argument_group ( 'build directories' )
   builddirs_arg   = builddirs_group.add_argument

   builddirs_arg (
      '--shlib-root', '-S', metavar='<dir>', dest='shlib_root',
      default=os.getcwd(), type=is_fs_dir,
      help="shlib root directory [%(default)s]",
   )

   builddirs_arg (
      '--build-dir', metavar='<dir>', dest='build_dir',
      default=UNSET, type=couldbe_fs_dir,
      help="directory for build files [<shlib root>/build/_generate]",
   )

   builddirs_arg (
      '--dest-dir', metavar='<dir>', dest='dest_dir',
      default=UNSET, type=couldbe_fs_dir,
      help=(
         'directory where generated files will be written to '
         '[<shlib root>/build/outdir]'
      )
   )

   builddirs_arg (
      '--recipe-file', metavar='<file>', dest='recipe_file',
      default=UNSET, type=couldbe_fs_file,
      help="recipe file to write [<build dir>/recipe]",
   )


   build_group = parser.add_argument_group ( 'build script options' )
   build_arg   = build_group.add_argument

   build_arg (
      '--shlibcc', metavar='<name|executable>', dest="shlibcc",
      default="shlib",
      help="name of/path to shlibcc",
   )

   build_arg (
      '--bash', dest="prefer_bash", default=False, action='store_true',
      help="prefer bash modules",
   )

   build_arg (
      '--no-color', dest='no_color', default=False, action='store_true',
      help="disable colored output",
   )

   target_group = parser.add_argument_group ( 'target options' )
   target_arg   = target_group.add_argument

   ## non-windows
   target_arg (
      '--libdir' , metavar='<dir>', dest='target_shlib_dir',
      default='/usr/lib/shlib',
      help="target shlib directory",
   )

   target_arg (
      '--shlib-name', metavar='<name>', dest='target_shlib_name',
      default='shlib.sh',
      help="target shlib name",
   )

   subparsers = parser.add_subparsers (
      title="commands", dest="command", help="action to perform"
   )

   recipe_parser = subparsers.add_parser (
      "recipe", help="create recipe"
   )
   recipe_parser.add_argument (
      "posargs", nargs="+", metavar='<spec>',
      help="comma-separated build spec(s)",
   )
   recipe_parser.add_argument (
      '-0', '--stdout', dest='recipe_stdout',
      default=False, action='store_true',
      help='print recipe to stdout instead of writing it to a file',
   )

   build_parser = subparsers.add_parser (
      "build", help="build existing recipes",
   )
   build_parser.add_argument (
      "posargs", nargs="+", type=is_fs_file, metavar='<file>',
      help="recipes to build",
   )

   make_parser = subparsers.add_parser (
      "make", help="create recipe and build it"
   )
   make_parser.add_argument (
      "posargs", nargs="+", metavar='<spec>',
      help="comma-separated build spec(s)",
   )

   return parser
# --- end of get_argument_parser (...) ---

class BuildRecipe ( object ):

   @classmethod
   def from_spec ( cls, destdir, specs ):
      instance = cls ( destdir )
      for spec in specs:
         instance.add_spec ( spec )
      return instance
   # --- end of from_spec (...) ---

   def __init__ ( self, destdir ):
      super ( BuildRecipe, self ).__init__()
      self.lines = [
         '#!/bin/sh',
         'set -e',
         '',
         'BUILD_API 0',
         'DENY_INHERIT',
         'SET_DEFAULTS',
         'INTO ' + quote_str ( '/' + destdir ),
         '',
         '### end header ###',
         '',
      ]

      self.add = self.lines.append

      self.instruction_map = {
         'link'                        : self.link_shared,
         'link_shared'                 : self.link_shared,
         'link_shared_lib'             : self.link_shared_lib,
         'dolib'                       : self.dolib,
         'standalone'                  : self.standalone,
         'x'                           : self.standalone,
         'inherit'                     : self.inherit_recipe,
         'use'                         : self.inherit_recipe,
         'stdlib'                      : self.depend_on_shlib,
         'splitlib'                    : self.splitlib,
         'splitlib_script'             : self.splitlib_script,
         'splitlib_x'                  : self.splitlib_script,
         'sx'                          : self.splitlib_script,
         'splitlib_script_with_stdlib' : self.splitlib_script_with_stdlib,
         'splitlib_xstd'               : self.splitlib_script_with_stdlib,
         'sxstd'                       : self.splitlib_script_with_stdlib,
         'symstorm'                    : self.symstorm,
      }
   # --- end of __init__ (...) ---

   def add_command ( self, *argv ):
      self.add (
         ' '.join ( quote_str ( arg ) for arg in argv if arg is not None )
      )
   # --- end of add_command (...) ---

   def depend_on_shlib ( self ):
      self.add ( "HAVELIB_SHLIB || MAKELIB_SHLIB" )
   # --- end of depend_on_shlib (...) ---

   def inherit_recipe ( self, recipe ):
      self.add_command ( "INHERIT", recipe )
   # --- end of inherit_recipe (...) ---

   def standalone ( self, script, destname=None ):
      self.add_command ( "STANDALONE", script, destname )
   # --- end of standalone (...) ---

   def link_shared ( self, script, destname=None, *lib_targets ):
      self.add_command ( "LINK_SHARED", script, destname, *lib_targets )
   # --- end of link_shared (...) ---

   def link_shared_lib ( self, script, destname=None, *lib_targets ):
      self.add_command ( "LINK_SHARED_LIB", script, destname, *lib_targets )
   # --- end of link_shared (...) ---

   def dolib ( self, *libname ):
      self.add_command ( "DOLIB", *libname )
   # --- end of dolib (...) ---

   def splitlib ( self, script, destname=None, *modules_exclude ):
      # standalone lib
      self.add_command (
         "SPLITLIB", script, ( destname or script ), *modules_exclude
      )
   # --- end of splitlib (...) ---

   def splitlib_script ( self,
      script, lib_destname=None, script_destname=None,
      modules_exclude=(), lib_targets=()
   ):
      self.splitlib ( script, lib_destname, *modules_exclude )
      self.link_shared (
         script, script_destname, ( lib_destname or script ), *lib_targets
      )
   # --- end of splitlib_script (...) ---

   def splitlib_script_with_stdlib ( self,
      script, lib_destname=None, script_destname=None,
      modules_exclude=(), lib_targets=()
   ):
      self.splitlib_script (
         script, lib_destname=lib_destname, script_destname=script_destname,
         modules_exclude=modules_exclude,
         lib_targets=( lib_targets + ( '${TARGET_SHLIB_NAME:?}', ) ),
      )
   # --- end of splitlib_script_with_stdlib (...) ---

   def symstorm ( self, script, *link_names ):
      self.add_command ( "SYMSTORM", script, *link_names )
   # --- end of symstorm (...) ---

   def gen_lines ( self ):
      for line in self.lines:
         yield line
      yield ""
   # --- end of gen_lines (...) ---

   def get_str ( self ):
      return '\n'.join ( self.gen_lines() )
   # --- end of get_str (...) ---

   def add_spec ( self, spec ):
      assert spec
      cmd_str, *args = [ ( k if k else None ) for k in spec.split ( ',' ) ]

      try:
         cmd_func = self.instruction_map [cmd_str.lower()]
      except KeyError:
         die ( "no such command: {!r}".format ( cmd_str ) )

      cmd_func ( *args )
   # --- end of add_spec (...) ---

# --- end of BuildRecipe ---

class ScriptGenerationRuntime ( object ):

   @classmethod
   def default_main ( cls, argv=None ):
      p = get_argument_parser()
      if argv is None:
         raw_config = p.parse_args()
      else:
         raw_config = p.parse_args ( argv )

      instance = cls ( config=vars ( raw_config ) )
      return instance.run_main()
   # --- end of default_main (...) ---

   def __init__ ( self, *, config ):
      super ( ScriptGenerationRuntime, self ).__init__()
      shlib_root     = config ['shlib_root']
      shlib_root_sub = lambda *rel: os.path.join ( shlib_root, *rel )
      config_or_sub  = lambda k, rel: (
         config[k] if k in config else shlib_root_sub ( *rel )
      )

      self.shlib_root           = shlib_root
      self.build_dir            = config_or_sub ( 'build_dir',
         ( 'build', '_generate' )
      )
      self.recipe_file          = (
         config ['recipe_file'] if 'recipe' in config
         else os.path.join ( self.build_dir, 'recipe' )
      )
      self.recipe_stdout        = config.get ( 'recipe_stdout', False )
      self.dest_dir             = config_or_sub ( 'dest_dir',
         ( 'build', 'outdir' )
      )
      self.shlib_libdir         = shlib_root_sub ( "lib" )
      self.shlib_scriptdir      = shlib_root_sub ( "scripts" )
      self.shlib_buildscriptdir = shlib_root_sub ( "build-scripts" )
      self.buildvars_exe        = os.path.join (
         self.shlib_buildscriptdir, "buildvars.sh"
      )
      self.shlibcc_exe          = config ['shlibcc']
      self.shlibcc_args         = ( '--strip-virtual', '-u', '--as-lib', )
      self.prefer_bash          = config ['prefer_bash']
      self.no_color             = config ['no_color']

      self.target_shlib_dir     = config ['target_shlib_dir']
      self.target_shlib_name    = config ['target_shlib_name']
      ##self.target_bindir        = config ['target_bindir']

      self.command              = config ['command']
      self.posargs              = config.get ( 'posargs', None )
   # --- end of __init__ (...) ---

   def get_buildvars_extra_env ( self, merge_with=None ):
      def bval_func ( val_true, val_false ):
         return lambda k: val_true if k else val_false
      # --- end of bval_func (...) ---

      sh_interpreter = '/bin/bash' if self.prefer_bash else '/bin/sh'
      shbool   = bval_func ( 'y', 'n' )
      flagbool = bval_func ( '+', '-' )

      buildvars_env = {
         'TARGET_SHLIB_NAME'          : self.target_shlib_name,
         'TARGET_SHLIB_ROOT'          : self.target_shlib_dir,
         'TARGET_SHLIB_LIBDIR'        : self.target_shlib_dir,
         'D'                          : self.dest_dir,
         'SCRIPT_INTERPRETER'         : sh_interpreter,
         'DEFAULT_SCRIPT_INTERPRETER' : sh_interpreter,
         'SCRIPT_SET_U'               : 'y',
         'SCRIPT_USE_BASH'            : shbool ( self.prefer_bash ),
         'NO_COLOR'                   : shbool ( self.no_color ),
         'USE'                        : (
            '{os} {bash}bash {nounset}nounset'.format (
               os      = os.environ.get ( 'USE', '' ),
               bash    = flagbool ( self.prefer_bash ),
               nounset = flagbool ( True ),
            ).lstrip()
         ),
      }

      if merge_with:
         buildvars_env.update ( merge_with )

      return buildvars_env
   # --- end of get_buildvars_extra_env (...) ---

   def build_recipe (
      self, recipe_file, *, dobuild_args=(), env=None, env_extend=None
   ):
      # note that buildvars uses the CC wrapper script, so $SHLIBCC is
      # disrespected there
      autodie_command (
         self.buildvars_exe, '--force', self.shlib_root, self.build_dir,
         '--chainload', 'dobuild-ng', recipe_file, *dobuild_args,
         env=env, env_extend=self.get_buildvars_extra_env ( env_extend )
      )
   # --- end of build_recipe (...) ---

   def call_shlibcc ( self, *args, env=None, env_extend=None ):
      autodie_command (
         self.shlibcc_exe, '-S', self.shlib_libdir,
         *( self.shlibcc_args + args ),
         env=env, env_extend=env_extend
      )
   # --- end of call_shlibcc (...) ---

   def run_main ( self ):
      COMMAND = self.command

      if COMMAND == 'recipe':
         recipe     = BuildRecipe.from_spec ( self.dest_dir, self.posargs )
         recipe_str = recipe.get_str()
         if self.recipe_stdout:
            sys.stdout.write ( recipe_str )
         else:
            with open ( self.recipe_file, 'wt' ) as FH:
               FH.write ( recipe_str )

      elif COMMAND == 'make':
         recipe     = BuildRecipe.from_spec ( self.dest_dir, self.posargs )
         recipe_str = recipe.get_str()

         with open ( self.recipe_file, 'wt' ) as FH:
            FH.write ( recipe_str )

         self.build_recipe ( self.recipe_file )

      elif COMMAND == 'build':
         for recipe_file in self.posargs:
            self.build_recipe ( recipe_file )
      else:
         die ( "unknown command {}".format ( self.command ) )


      return os.EX_OK
   # --- end of run_main (...) ---

# --- end of ScriptGenerationRuntime ---

if __name__ == '__main__':
   ScriptGenerationRuntime.default_main ( sys.argv[1:] )
