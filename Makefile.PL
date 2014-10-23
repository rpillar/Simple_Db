use 5.006;
use strict;
use warnings FATAL => 'all';
use inc::Module::Install;

name     'Simple-Db';
all_from 'lib/Simple/Db.pm';
author   q{Richard Pillar <richardpillar@googlemail.com>};
license  'artistic2';

perl_version 5.006;

tests_recursive('t');

resources (
   #homepage   => 'http://yourwebsitehere.com',
   #IRC        => 'irc://irc.perl.org/#Simple-Db',
   license    => 'http://www.perlfoundation.org/artistic_license_2_0',
   #repository => 'git://github.com/Richard Pillar/Simple-Db.git',
   bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Simple-Db',
);

configure_requires (
   'Module::Install' => 0,
);

build_requires (
   'Test::More' => 0,
);

requires (
   #'ABC'              => 1.6,
   #'Foo::Bar::Module' => 5.0401,
);

install_as_cpan;
auto_install;
WriteAll;
