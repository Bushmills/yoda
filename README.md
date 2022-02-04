# yoda

yoda is an acronym of Yet Onather Delirious Application, and does
naturally not refer to any greenish midget with pointy ears, albeit it had
been said that reading yoda source aloud sounds like the very same midget
talking.

yoda implements a compiler which converts a close resemblance of Forth
source code to bash functions, an interpreter which runs them, and a base
vocabulary of useful functions, strongly orientated towards what a common
Forth interpreter offers.  It can be used to augment bash, can serve as
shell, or as Forthish coding environment.

yoda facilitates exploring it, by providing words for examining misc
aspects, described on the [Explore wiki page](https://github.com/Bushmills/yoda/wiki/Explore).

In some respects does yoda differ from Forth.  Some example code, giving
more tangible clues where and how yoda differs from Forth can be reached
from this [Examples wiki page](https://github.com/Bushmills/yoda/wiki/Examples)  
Differences are listed and commented on the [Differences wiki page](https://github.com/Bushmills/yoda/wiki/Differences).  
My musings, ideas, plans and thoughts of possible changes can be found at
[Considerations wiki
page](https://github.com/Bushmills/yoda/wiki/Considerations), and the rest possibly
among the [remaining wiki pages](https://github.com/Bushmills/yoda/wiki/Home).

yoda has been coded as bash script with only a small count of [external dependencies](https://github.com/Bushmills/yoda/blob/main/DEPENDENCIES)  

Here's a screenshot showing yoda's status line, the current list of words, and a "word not found" error.
Some of those words were compiled from library when a word needing them was executed, and are, therefore, not part
of yoda's "core" vocabulary:  
![words and error screenshot](http://snap.scarydevilmonastery.net/github/1643883173174493618d.png)
