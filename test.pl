# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 1 };
use Autodia;
use Autodia::Diagram;
use Autodia::Diagram::Class;
use Autodia::Diagram::Object;
use Autodia::Diagram::Dependancy;
use Autodia::Diagram::Inheritance;
use Autodia::Diagram::Superclass;
use Autodia::Diagram::Component;
use Autodia::Handler;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

