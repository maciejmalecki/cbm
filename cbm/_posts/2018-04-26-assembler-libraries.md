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

What is a library?
------------------
Library is just a piece of code that anybody can reuse in other projects just to boost productivity. There are few assumptions that everybody should consider: such code must offer stable API, must be properly versioned (such as I need to use exact version 1.4.0, nothing older but also nothing newer).

What does it mean in practice?

* We need to use any form of source control (GIT and [GitHub] with its "Releases" feature fits here perfectly).
* It would be great to have central repository of libraries and dependency management tool just to be able to install or upgrade a library with single CLI command (there are a lot of solutions for other languages such as NPM for JavaScript, PIP for Python, Gems for Ruby, Maven Nexus for Java but sadly nothing for C64 assembly).
* It would be great that we can integrate assembling and dependency management process into one tool so that we can write "builds" (like with maven, gulp, angular cli, rake).

Later I will show, how can we at least partially address these issues for KickAssembler-written libs.

What should we put into library?
--------------------------------
In order to create flexible solution I decided that I will always wrap assembly code in macro while in library. This has two major advantages:
* Macros can be parametrized, which gives us additional flexibility.
* We have full freedom where to use macro and thus where in memory will resulting code be located.

Let's assume we have following code in our library:

	.macro inc16(destination) {
	  inc destination
	  bne !+
	  inc destination + 1
	!:
	}

It increments 16 bit number placed in memory in two memory cells: ```destination``` and ```destination+1``` (little endian). Every time it is used it will be exchanged with 3 instructions weighting 8 bytes in total. Of course we can use such "library call" many times, each time we're adding 8 bytes to total length of our code.

There are two more useful types of items we can declare in our library. 

[KickAssembler] offers functions, that itself does not evaluate into assembly code but can calculate values that can be later used as immediate value in assembly or in macros.

Lets's consider following function:

	.function getTextMemory(screenMem, charSet) {
	  .return charSet<<1 | screenMem<<4
	}
	
What it does it takes screenMemory slot and charsetSlot and combines it together to get value that can be then stored in ```$D018``` register of VIC-II. This can be used for every 3 text modes of C64. This is how we can use it in code:

	lda #getTextMemory(1, 4)
	sta MEMORY_CONTROL

Or we can even wrap it into library macro:

	.macro configureTextMemory(screenMem, charSet) {
	  lda #getTextMemory(screenMem, charSet)
	  sta MEMORY_CONTROL
	}

and then use in code like this:

	configureTextMemory(1, 4)

Last useful item is label. Labels can be used to define constants that can be then reused in different part of library, other libraries or programs. It is definitely easier to read ```sta MEMORY_CONTROL``` instead of ```sta $D017```, isn't it?

Here's example: a beginning of declaration for all VIC-II registers:

	/* ------------------------------------
	 * VIC-II registers.
	 * ------------------------------------ */
	.label VIC2                 = $D000 
	.label SPRITE_0_X           = VIC2 + $00 
	.label SPRITE_0_Y           = VIC2 + $01 
	.label SPRITE_1_X           = VIC2 + $02 
	.label SPRITE_1_Y           = VIC2 + $03 
	.label SPRITE_2_X           = VIC2 + $04 

	
How can we write libraries in assembly?
---------------------------------------
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

Small problems
--------------
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

How to use library (in another library)
---------------------------------------
Assuming you have checked out a library into some common library directory of your choice, using it in your code is relatively simple. Look at my directory structure where I have checked out my libraries:

![Content of lib dir]({{ "/cbm/img/travis-ci/library-directory.png" | absolute_url }})

When using KickAssembler from command line you use ```-libdir``` parameter to specify ```c64lib``` directory location (in my case) and you can write your source code like this:

	#import "chipset/vic2.asm"
	#import "chipset/sprites.asm"
	#import "chipset/cia.asm"
	#import "common/mem.asm"

	*=$0801 "Basic Upstart"
		:BasicUpstart(start)

	*=$0810 "Asm Program"
	start: {
		jsr initialize
	loop:
		inc c64lib.BORDER_COL
		nop
		nop
		nop
		nop
		nop
		nop
		jmp loop
	}

	initialize: {
		sei
		cli
		rts
	}

You see: because inside ```c64lib``` dir you have ```chipset``` and ```common``` checked out, and inside you have ```vic2.asm```, ```sprites.asm```, ```cia.asm``` and ```mem.asm``` respectively, all works perfectly (KickAssembler will find these files to include them). All you need to do is to launch it in following way:

	java -jar KickAss.jar -libdir c:\c\c64lib test.asm
	
If you use IDE such as [Relaunch64], you must customize Compile & Run Scripts in following way:

![How to customize Relaunch64]({{ "/cbm/img/travis-ci/relaunch64.png" | absolute_url }})


Bring some automation with Travis CI
------------------------------------
Interesting part starts actually here. [TravisCI] is a CI environment that is very well integrated with [GitHub]. It is also free for public repositories, so as long as we're doing Open Source, we don't have to invest - cool. Once you integrate Travis with your GIT repository, it will start watching for pushes (on any branch, pull request, tag, etc). When new push is detected, it scans your repository for ```.travis.yml``` configuration file and according to what's inside provides your own temporary little linux machine on which you can actually do anything. Most likely you do a build of your software, you can even launch it and test it if you wish.

Travis comes with plenty of predefined environments so that you can easily build Java/Maven projects, Ruby, Python, C++ and so on. Surprisingly, there is no environment for KickAssembler available (ha ha ha). Then I actually found, that it is not so easy to provide one, because KickAssembler is a Java application and JVM is available on any Travis environment out of the box! All we need to do is to download KickAssembler at the beginning of our builds and then just use it to build any ```asm``` file you wish.

I have encapsulated this functionality in separate GIT hub repo:

<https://github.com/c64lib/travis-ci>

There is actually some documentation provided how to use (see README). What is important, to use this functionality you must provide ```.travis.yml``` file with similar content:

```yml
language: asm
sudo: false
before_install:
  - source <(curl -SLs https://raw.githubusercontent.com/c64lib/travis-ci/master/install.sh)
script:
  - cpm common https://github.com/c64lib/common/archive/develop.tar.gz
  - cpm chipset https://github.com/c64lib/chipset/archive/develop.tar.gz
  - ka -libdir cpm_modules test.asm
notifications:
  email:
     on_success: change
     on_error: change
```

First important line is this one:
```bash
source <(curl -SLs https://raw.githubusercontent.com/c64lib/travis-ci/master/install.sh)
```
It downloads ```install.sh``` script from repo and sources it (it means it will be immediately executed inside Travis CI environment). What this script does, it download KickAssembler binaries and provides your scripting environment with two further commands: ```cpm`` and ```ka```.

The ```ka``` command is just a wrapper for KickAssembler (who wants to type ```java -jar KickAss.jar ...?) - you now just type ```ka``` and pass all valid KickAssembler parameters to it.

The ```cpm``` command is a very simple tool for managing dependencies. It actually very limited - what it does now, it download specified library from GitHub, unzip it and places in hidden ```.cpm_modules``` directory (JavaScript and NodeJS people already know what is going on;-). Actually it is so limited (I wrote it and tested in 15 minutes), that you must provide it with library name manually, see:

```bash
  - cpm chipset https://github.com/c64lib/chipset/archive/develop.tar.gz
```
(this one downloads content of ```develop``` branch of ```chipset``` library and unzips it under ```.cpm_modules\chipset```).

Because now we are always launching kick assembler in following way:
```bash
  - ka -libdir cpm_modules test.asm
```
you can reference a library with following import:

	#import "chipset/vic2.asm"
	
Still, because this facility is very limited, it is useful only for remote builds (CI) on TravisCI. However, I plan to enhance it to be a CLI interface for development environment. But for this you have to wait a while.

You can refer test library on GitHub:

<https://github.com/c64lib/test>

[KickAssembler]: http://www.theweb.dk/KickAssembler/Main.html
[Relaunch64]: http://www.popelganda.de/relaunch64.html
[Codebase64]: http://codebase64.org
[CovertBitops]: https://cadaver.github.io/ "Covert Bitops"
[64bites]: https://64bites.com/
[GitHub]: https://github.com
[TravisCI]: https://travis-ci.org