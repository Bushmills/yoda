# yoda
yoda is an acronym of Yet Onather Delirious Application, and does naturally not refer to any greenish midget with pointy ears,
albeit it had been said that reading yoda source aloud sounds like the very same midget talking.

yoda implements a compiler which converts a close resemblance of Forth source code to bash functions,
an interpreter which runs them, and a base vocabulary of useful functions, strongly orientated towards
what a common Forth interpreter offers. It can be used to augment bash, can serve as shell, or as Forthish
coding environment.

In some respects does yoda differ from Forth:

- forward referencing of words, either only those compiled to new
  words, or also those called upon while interpreting. Feature can
  be enabled and disabled any time (disabled by default)

- strings. An additional string stack has been added, entering strings
  doesn't go through  s"  word. Instead are strings recognised and dealt
  with by a pattern matching mechanism, invoked on words not found in
  the dictionary. Literal numbers, ASCII values of single characters,
  shell commands are subject to the same mechanism.

- there is no virtual machine. Compiling a word creates a bash function,
  containing, from a bash viewpoint, "native code". The yoda interpreter
  operates within the same shell environment as the functions its
  compiler generates - yoda doesn't shell (unless bash does for invoking
  an external command).

- Due to its forward referencing capability does yoda not need all of
  the functionality necessary for compiling a program already prior to
  beginning of compilation. Instead can it resolve those after compilation
  on a need-to-include base. This allows for a more automatic and
  comfortable library inclusion management. The library "postlib",
  referenced during resolve passes, exists for this purpose: compile
  nothing from it, unless needed.
  Another library, prelib, is included before main source compilation.
  prelib is unsuited for resolving forward referenced words.

- yoda has no built-in interactive interpreter, but compiles an interpreter
  from library when needed (forward referenced). Its name is "quit".

- yoda has now eliminated immediate words. While the word "immediate"
  still exists and is used, its semantics are different: it causes moving
  the header of last word into the compiler context vocabulary, rather than
  marking the word as state smart. Such a word doesn't have interpret time
  semantics (and can't be found when not compiling). For interpret time
  semantics of such a word, create it again with identical name, and specify
  only those.

- not fully adhering to standard by sometimes deviating choice of word names.
  so is "read-file" called "from", "evaluate" evaluates from tib, not from addr/cnt,
  "list" isn't a word from the blocks word set (and doesn't behave like it),
  pictured number conversion is nestable (that is,  <# ... #>  may appear
  within another <# ... #> block), but doesn't expect a double length number.
  Each started conversion allocates a string stack item as output buffer.
  Some of those choice may not be permanent, but on a "for the time being" base.
