use Test::More;
BEGIN { use_ok( 'Net::Trustico' ); }

SKIP: {
    unless (exists $ENV{TRUSTICO_USERNAME} && exists $ENV{TRUSTICO_PASSWORD}) {
        skip "Env for Trustico authentication not present", 1;
    }

    my $t = Net::Trustico->new( username => $ENV{TRUSTICO_USERNAME},
                                password => $ENV{TRUSTICO_PASSWORD});

    is($t->hello(), 1, "Hello test passed");
}

done_testing();
