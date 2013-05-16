.. _shlibcc at github:
   https://github.com/dywisor/shlibcc

.. _shlib git repo:
   https://github.com/dywisor/shlib

.. sectnum::

.. contents::
   :backlinks: top

==============
 Introduction
==============

shlib, the *shell module library*, is a project that aims to provide reusable
shell code in modular form, thus allowing to create small scripts as well as
big library files.

Its features range from basic functions like *die()* known from Perl,
generic iterators, file system manipulation and colored messages to more
complex functionality such as squashfs containers and initramfs code, including
*liram*, a distribution-agnostic approach to load a system into tmpfs.

Note, however, that using *shlib* tends to result in long scripts (more than
1000 lines of text), so if you are convinced that shell scripts should not
exceed *N* lines of code (where *N* is 50, 100, ...), then this project may
not be suited for you.


=============
 Using shlib
=============

This section is mainly centered on using *shlibcc* in conjunction with
*shlib*, but also covers how users can include modules in their own scripts.

---------------
 Prerequisites
---------------

* a sh-compatible command interpreter, e.g. bash or dash
* a *module linker* that somehow puts *shlib modules* together

  This will most likely be *shlibcc*, a linker written in Python that features
  dependency resolution and basic code modification at script creation time.
  See `shlibcc at github`_ for details.
* git for getting shlib/shlibcc
* python docutils 0.9 or later for generating doc files

------------------------------
 Installing shlib and shlibcc
------------------------------

The following code snippet gives an idea of how to *install* shlib and shlibcc.

..  code:: text

   # project root directory
   PRJROOT="${HOME?}/project"
   [ -d "${PRJROOT}" ] || mkdir "${PRJROOT}"

   # get shlib
   git clone --depth 1 git://github.com/dywisor/shlib.git "${PRJROOT}/shlib"

   # get local shlibcc
   git clone --depth 1 git://github.com/dywisor/shlibcc.git "${PRJROOT}/shlibcc"

   cd "${PRJROOT}/shlib"

---------------------
 shlib repo overview
---------------------

Now that you have cloned the `shlib git repo`_,
you might wonder what all these files and directories are good for.

The top level directory contains helper scripts for building scripts or
libary files, amongst others:

..  table:: helper scripts

   +----------------------+--------------------------------------------------+
   | script / file        | description                                      |
   +======================+==================================================+
   | CC                   | *shlibcc* wrapper script                         |
   |                      |                                                  |
   |                      | It will try to find shlibcc in your ``PATH`` and |
   |                      | if that fails at ``../shlibcc/shlibcc.py``       |
   +----------------------+--------------------------------------------------+
   | Makefile             | Script and library creation                      |
   +----------------------+--------------------------------------------------+
   | find-not-included.sh | Find and list modules that are not part of the   |
   |                      | big library file                                 |
   +----------------------+--------------------------------------------------+
   | generate_script.sh   | Generate scripts                                 |
   +----------------------+--------------------------------------------------+
   | loader.sh            | Load *shlib* modules dynamically. Do **not** use |
   |                      | this as it has some restrictions.                |
   +----------------------+--------------------------------------------------+
   | make_scripts.sh      | Build a series of scripts (or all scripts).      |
   |                      | Used by the Makefile.                            |
   +----------------------+--------------------------------------------------+

The actual content of the *shlib* repo is organized in four subdirectories:

.. table::

   +-----------+-------------------------------------------------------------+
   | directory | description                                                 |
   +===========+=============================================================+
   | /doc      | Documentation                                               |
   +-----------+-------------------------------------------------------------+
   | /files    | Additional data like config files and init scripts          |
   +-----------+-------------------------------------------------------------+
   | /lib      | Module root directory                                       |
   +-----------+-------------------------------------------------------------+
   | /scripts  | Script *templates*. Most of them need modules from lib/.    |
   +-----------+-------------------------------------------------------------+


---------------------
 Basic shlibcc usage
---------------------

Putting shlib modules manually together is not a trivial task. One has to
examine *all* dependencies of *all* required modules and determine an order
in which the modules should be included.
Furthermore, code processing may be useful, e.g. dropping "useless" comments.
With increasing number of modules involved, things get complex quickly.

That's why you definitely want to use *module linker* that performs the
actions listed above automatically. *shlibcc* is a project with the aim to
implement such a linker. It is also the name of the linker that will be used
throughout this guide.

The basic shlibcc usage is:

.. code:: sh

   # combine the listed modules
   shlibcc.py [option...] module [module...]

   # create a standalone script
   shlibcc.py [option...] --depfile --main <file>

   # combine module(s) read from <file>
   shlibcc.py [option...] --depfile <file>

*module* can be a module name, e.g. ``fs/dodir``, or a directory path
relative to the library, e.g. ``fs``.

shlibcc's accepts many options, most notably:

--help
   Print shlibcc's help message which lists all options.

--output <file>, -O <file>
   Output file to write, ``-`` for stdout (default).

--main <file>
   Add code from *file* to the created script's body.

--depfile <file>
   Read extra dependencies from <file>.

--depfile
   Read the main script's dependencies.

--stable-sort
   Use stable sorting, which results in totally ordered module dependencies.
   Useful for comparing output files, e.g. when creating patches.

--as-lib, -L
   Use this to indicate that the result will be a library file.

--strip-virtual
   Remove modules that contain no code

--strip-comments
   Remove all comments

--keep-dev-comments
   Keep dev notes. These are usually extra comment lines and todo notes.

--header-file <header>, -H <file>
   Use a custom header file.

--short-header
   Write a minimal header.

   ..  Note::

      The minimal header lacks licensing information.

--bash
   Prefer bash module files where available. This also changes the shebang
   to ``#!/bin/bash``.

--ash
   Sets the shebang to ``#!/bin/busybox ash``.

--exclude <module>, -x <module>
   Forcefully exclude a module (referenced by name) from dependency considerations.
   Can be specified more than once.

--shlib-dir <dir>, -S <dir>
   shlib root directory. Automatically set by the ``CC`` wrapper script.

--link
   Combine modules (optionally with a main file).
   This is the default action.

--deplist
   Instead of ``--link``: list modules that would be combined, in order.


It is recommeded to use the ``CC`` wrapper script that sets some options,
e.g. ``--shlib-dir``, automatically.

-------------------------------
 Creating the big library file
-------------------------------

Simply run

..  code:: sh

   make shlib
   # optionally followed by
   make verify
   #or, as a single call, make shlib verify


and copy ``./build/shlib_YYYY-MM-DD.sh`` to ``${dest_file}``.

You can also call *shlibcc* directly via

..  code:: sh

   ./CC --as-lib --strip-virtual --stable-sort all -O ${dest_file}


.. Warning::

   It's possible to create a libary file that contains the entire module
   library and is considerably bigger than the *big library file*
   This is not recommended as it includes very specific modules (e.g.
   the initramfs code) as well as any *local* module(s).


..  _script generation:

-------------------------------------
 Creating one of the example scripts
-------------------------------------

.. code:: sh

   # (A) print generate_script's usage information
   ./generate_script.sh --help

   # (B) list available scripts
   ./generate_script.sh -l

   # (C) create a standalone script
   ./generate_script.sh -S <script name>

   # (D) create a script that uses a shared (or separate) shlib file
   #  which has to be created manually
   ./generate_script.sh -L <shlib file> <script name>

   # (E) create a library file for <script name>
   ./CC -L --strip-virtual --stable-sort -D ./scripts/<script name>.depend -O <shlib file>


The various creation methods listed above lead to the definition of the
following script *types*:

standalone
   A (big) script that has no runtime shlib dependencies (#C).

split-lib
   #E combined with #D. The result is a standalone script
   whose library is split from the main script.
   The path to this library has to be specified at script generation time.

linked
   The *all* library combined with #D. The script's dependencies have to be
   a subset of what's provided by the library file (this won't be checked!).
   The path to the *all* library has to be specified at script generation time.

manual
   Result of using *shlibcc* directly (or not using it at all) plus *somehow*
   including the module code in a script file.
   Just listed here for completeness, you're on your own when using this type.

-------------------------------------
 Creating all of the example scripts
-------------------------------------

There's an easy way to build all scripts found in the ``scripts`` directory:

..  code:: sh

   # create standalone scripts
   make scripts-standalone

   # create linked scripts
   make DEST=<shile file> scripts-linked


Any of the above commands creates all scripts in ``build/scripts``.


--------------------------
 Creating a custom script
--------------------------

This section describes how to add a script as *template* and build it
afterwards. This is one possible solution for creating custom scripts.
Refer to the previous chapters for alternatives.

A script *template* usually consists of two files, a *code file* that contains
the script's functionality and a *dependency file* that lists all required
shlib modules. These files have to be put into the same directory. The code
file's name must be exactly ``<script name>.sh``, whereas the dependency file's
name must be ``<script name>.depend``.

You can then create the script using already known methods, e.g. as a
standalone script:

.. code:: sh

   ./CC [option...] --main <script name>.sh --depfile


Another (and more convenient) way is to put your script into the ``scripts``
directory, preferably into ``scripts/local``.
This allows to use ``generate_script.sh`` as described in `script generation`_.

=================
 Module Overview
=================

TODO; lib/ dir

-----------------
 Virtual modules
-----------------

++++++++++++++++++
 The "all" module
++++++++++++++++++

TODO


==========================
 Script Template Overview
==========================

TODO; scripts/ dir


========================================
 Shlib Style Guide and Coding Reference
========================================

TODO
