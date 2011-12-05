# blat - A static site generation tool

Yes, there are lots of static site generation tools. This one is mine. If you like it, it can be yours too.

Instead of going into what blat does, I'll show you if you'd like to follow this example.

## Getting blat

Clone the repository:

    $ cd /tmp/
    $ git clone git://github.com/andychilton/blat.git

Or:

    $ git clone https://github.com/andychilton/blat.git

## Starting a new Project

Let's create a site called fluffysquirrels. This site will show cute pictures of squirrels that have cute fluffy cute
tails. You get the idea. You may put some LOL text on the images too if you like.

    $ cd /tmp/
    $ mkdir fluffysquirrels
    $ cd fluffysquirrels

That's the start of your project. But now we need to know where our files live.

## Directory Layout

Even though blat can be told where your directories are, it also has defaults so let's use them. You'll need three
directories for your content, your templates, your static files and a directory for your site (where the generated
pages will be saved to):

    $ mkdir src template static htdocs

Let's run 'blat' on it's own:

    $ /tmp/blat/bin/blat
    $

Nothing happens since we don't have anything to do. So let's run it with verbose on so we can see what is happening:

    $ /tmp/blat/bin/blat -v
    --- Copying Static Files -------------------------------------------------------
    --- Finding Files -------------------------------------------------------------
    --- Processing Files ----------------------------------------------------------
    --- Processing Sections -------------------------------------------------------
    --- Finished ------------------------------------------------------------------
    $

As you can see from the above set of messages there are 4 stages to blat's processing. It firstly tries to find all of
your static files and copies those into 

But where does blat find all of these files? Just do a --help to see the options and the defaults:

    $ /tmp/blat/bin/blat --help
    ...
     -t, --static           the static directory (default: static)
     -s, --src              the source directory (default: src)
     -d, --dest             the destination directory (default: htdocs)
     -t, --template         the template directory (default: tt)
    ...

(Ends)
