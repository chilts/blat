use inc::Module::Install;

name     'HTML-Blat';
all_from 'lib/HTML/Blat.pm';
author   'Andrew Chilton <andychilton@gmail.com>';

build_requires 'Test::More';

auto_install;

WriteAll;

