package Net::Trustico;

use strict;
use warnings;
our $VERSION = '0.01';

use LWP::UserAgent;
use Carp qw/croak/;
use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw/username password/);

=head1 NAME

Net::Trustico - Perl extension for ordering SSL certificates from Trustico
via their API.

=head1 SYNOPSIS

  use Net::Trustico;
  
  my $t = Net::Trustico->new( username => $user, password => $pass );

  my $products = $t->products();

  $t->hello( $testString );

  my %result = $t->order( product => $product,
                          csr => $csr,
                          period => 12,
                          approver => 'admin@example.com',
                          insurance => 0,
                          servercount => 1,
                          admin => $a,
                          tech => $t,
                          novalidation => 0
                          );

  my $status = $t->status( orderid => $id );

=head1 DESCRIPTION

Perl module for ordering SSL certificates from Trustico.

=head1 METHODS

=head2 new

=head2 hello

Tests the connection to the Trustico API by sending a string of text and
testing that the same string is returned.

This function returns true if the connection is OK or false if not.

You can call this method with a string of your own or no parameters. If
no parameters are passed a standard string is used to test the connection.

=head2 order

Submits an order to the Trustico API and returns a hash reference 
confirming order details on success or undef.

See the Trustico documentation for relevent fields but note that the
Admin and Tech contacts should be passed as hash references rather than
individual fields.

=head2 status

Gets the status of the order specified by the orderid parameter.

The returned details are in a hash reference.

=head2 products

Returns a hash reference containing a list of product codes and the 
product name for each code.

=head1 SEE ALSO

http://www.trustico.com/


=head1 AUTHOR

Jason Clifford, E<lt>jason@Eukfsn.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Jason Clifford

This library is free software; you can redistribute it and/or modify
it under the terms of the FSF GPL version 2.0 or later.

=cut

sub new { shift->SUPER::new({ @_ }) }

sub hello {
    my ( $self, $string ) = @_;

    $string = "Net::Trustico test string" unless $string;

    my $res = $self->_req('Hello', { 'TextToEcho' => $string } );
    return undef unless $res->{SuccessCode} == 1;
    return undef unless $res->{TextToEcho} eq $string;
    return 1;
}

sub order {
}

sub status {
    my ($self, %args) = @_;
    return undef unless $args{orderid} || $args{issuerid};

    my $args = { };
    if ( $args{orderid} ) {
        $args->{OrderID} = $args{orderid};
    }
    else {
        $args->{IssuerOrderID} = $args{issuerid};
    }

    my $res = $self->_req('GetStatus', $args);
    return undef unless $res->{SuccessCode} == 1;
    # XXX Process returned data
}

sub _process_type_1 {
}

sub _process_type_2 {
}

sub _req {
    my ($self, $command, $args) = @_;

    my $a = {
        Command => $command,
        UserName => $self->username,
        Password => $self->password
    };

    foreach (keys %$args) {
        $a->{$_} = $args->{$_};
    }

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30);
    my $url = 'https://api.ssl-processing.com/geodirect/postapi/';

    my $res = $ua->post($url, $a);

    croak "Unable to connect to API" unless $res->is_success;

    my %rv = ();
    my @fields = split(/\n/, $res->content);
    foreach (@fields) {
        $_ =~ /(.*?)\|(.*?)\|/;
        $rv{$1} = $2;
    }

    return \%rv;
}

1;
