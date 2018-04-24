---
title: Writing and using libraries in KickAssembler
description: Here I explain how to write, use and build under travis-ci reusable libraries written in KickAssembler.
layout: post
---
It's a long way I took from early times when I coded something for MOS 65XX family to now, when I actually code for money. What was really a joy or hobby, now becomes a rather routine work guided by corporate processes, software frameworks and project management methodologies. I do not want to complain, I fully understand that productivity is a key and live is hard.

When I came back to C64 programming, and that was roughly two years ago (2016) I was just a little bit bored being sick listed because of backbone problems (something very common for programmers of my age). I jumped into very fast, watched bit of excellent [64bites], discovered a wonderful pair of [KickAssembler] and [Relaunch64] and then endless source of information, such as [Codebase64] and [CovertBitops], to mention just a few. 

To my great surprise I soon discovered, that something is missing: definitive some processes such as automated builds or CI (continous integration). I'm looking for ready to use, well tested libraries and dependency management system and couldn't find any. 

(However, I do not miss any management methodologies...)

Just to unlock my brain at this moment, I decided that:
* I will use [GitHub] to store and version my code
* I will use [TravisCI] to run continous integration of my code
* I will use excellent features of [KickAssembler] such as macros, functions and directives and try to write generic, reusable assembly code

Challenge accepted.

## What is a library?
Library is just a piece of code that anybody can reuse in other projects just to boost productivity. There are few assumptions that everybody should consider: such code must offer stable API, must be properly versioned (such as I need to use exact version 1.4.0, nothing older but also nothing newer).

What does it mean in practice?

* We need to use any form of source control (GIT and [GitHub] with its "Releases" feature fits here perfectly).
* It would be great to have central repository of libraries and dependency management tool just to be able to install or upgrade a library with single CLI command (there are a lot of solutions for other languages such as NPM for JavaScript, PIP for Python, Gems for Ruby, Maven Nexus for Java but sadly nothing for C64 assembly).
* It would be great that we can integrate assembling and dependency management process into one tool so that we can write "builds" (like with maven, gulp, angular cli, rake).

Later I will show, how can we at least partially address these issues for KickAssembler-written libs.

## How can we write library in KickAssembler?
There are three features of [KickAssembler] that are handy here:
* The ```#import``` directive that includes specified ```asm``` file into source code.
* The namespace feature that allows to isolate objects of library so that they don't clash with identically named objects of another library.
* The ```-libdir``` parameter that allows to specify additional directory where [KickAssembler] will look for files to import, so we can keep our libraries checked out in separate folder.

Lets look at trivial example: a common library without any additional dependencies: <https://github.com/c64lib/common>. It consists of several files:
* ```.gitignore``` - these are several build artifacts of KickAssembler that should never be stored in GIT such as ```*.prg``` and ```*.sym``` files but also a ```.cbm``` directory (I will explain that later).
* ```.travis.yml``` - config file for [TravisCI] - also to be described later.
* ```LICENSE```, ```README.md``` - speak for themselves.
* ```common.asm```, ```mem.asm``` - library files

First thing that we see is that it is actually possible to keep several library (asm) files in single 'library' module. Splitting code into few smaller files is always good as long as separation is semantically consistent and reasonable.

Take a look into ```common.asm``` - it is really trivial and short:

	#importonce
	.filenamespace c64lib

	/*
	 * Why Kickassembler does not support bitwise negation on numerical values?
	 * 
	 * Params:
	 * value: byte to be negated
	 */
	.function neg(value) {
		.return value ^ $FF
	}
	.assert "neg($00) gives $FF", neg($00), $FF
	.assert "neg($FF) gives $00", neg($FF), $00
	.assert "neg(%10101010) gives %01010101", neg(%10101010), %01010101
	
What is important is header: ```#importonce``` says that such file should be imported only once no matter how many times this particular library file is used by all other libraries and files used to assembly our project.

Then I declare a namespace: ```c64lib```. I decided to use single namespace for all my libraries because of the namespace problem I have discovered (described in details later). Having separate namespace per library will force me to declare all items 'public' which I wanted to avoid.

Then we have function documentation (quite important for libraries) - this is logical negation function, by some reason such function is not available in [KickAssembler] out of the box.

Then I wrote several tests in form of KickAssembler asserts: why not to write some unit tests if there is such possibility given by assembler?

## Small problems

Sadly there are few shortcommings of [KickAssembler] as for now (version 4.x), which make things a little bit more complicated.

Firstly, it is not possible to specify more than one diectory with ```-libdir``` switch. This is quite easy to workaround - either we need to checkout all libraries into single, common directory, or we can keep it separated and than assemble it into 'virtual folder' using symbolic links. 

Second problem is unfortunately more problematic. The namespace feature is great, as it allows to group labels, macros and functions. But macros and functions are not visible from outside of that particular namespace. So, when you write following code:

	.namespace c64lib {
	  .label VIC2 = $D000 
	  .label MEMORY_CONTROL = VIC2 + $18
	  .label TEXT_SCREEN_WIDTH = 40
	  
	  .function getTextOffset(xPos, yPos) {
	    .return xPos + TEXT_SCREEN_WIDTH * yPos
	  }

	  .macro configureTextMemory(video, charSet) {
	    lda #getTextMemory(video, charSet)
	    sta MEMORY_CONTROL
	  }
	}
	
you can then access label inside of the ```c64lib``` namespace:

	sta MEMORY_CONTROL
	
but you cannot call ```getTextOffset``` or ```configureTextMemory```, because function and macro names are not accessible from outside. User manual of KickAssembler says that this is 'current state', so there is a change this will be changed in one of future releases.

To overcome this limitation, we have to prepend function and macro name with ```@``` during its declaration which automatically places them in root namespace. In this way we can access it without prepending it with any namespace name, but as it becomes global, it can clash with other names easily. So there are pros and cons.

What is good, is that we actually have two kind of objects: public (prepended with ```@```) and private objects (hidden inside namespace) - we can then define public API of our library and keep the rest as freely modifiable private elements.

## Bring some automation with Travis CI

[KickAssembler]: http://www.theweb.dk/KickAssembler/Main.html
[Relaunch64]: http://www.popelganda.de/relaunch64.html
[Codebase64]: http://codebase64.org
[CovertBitops]: https://cadaver.github.io/ "Covert Bitops"
[64bites]: https://64bites.com/
[GitHub]: https://github.com
[TravisCI]: https://travis-ci.org