package Net::Trustico;

use strict;
use warnings;
our $VERSION = '0.01';

use LWP::UserAgent;
use Carp qw/croak/;
use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw/username password/);

my %products = (
    'freessl30' => {
        name => 'FreeSSL 30 Day Trial',
        periods => [ qw/1/ ],
        vetting => 'DOM',
        process => '1',
        reissuance => 0,
        canrenew => 0
    },
    'rapidssl' => {
        name => 'RapidSSL',
        periods => [ qw/12 24 36 48 60/ ],
        vetting => 'DOM',
        process => '1',
        reissuance => 1,
        canrenew => 1,
    },
    rapidsslwildcard => {
        name => 'RapidSSL Wildcard',
        periods => [ qw/12 24 36 48 60/ ],
        vetting => 'DOM',
        process => '1',
        reissuance => 1,
        canrenew => 1,
    },
    geotrust30 => {
        name => 'GeoTrust SSL 30 Day Trial',
        periods => [ qw/1/ ],
        vetting => 'DOM',
        process => '1',
        reissuance => 0,
        canrenew => 0
    },
    # XXX Need to add remaining products
    );

=head1 NAME

Net::Trustico - Perl extension for ordering SSL certificates from Trustico
via their API.

=head1 SYNOPSIS

  use Net::Trustico;
  
  my $t = Net::Trustico->new( username => $user, password => $pass );

  die unless $t->hello( $testString );

  my $a = {
    title => 'Ms',
    firstname => 'Eliza',
    lastname => 'Xample',
    organisation => 'E.Xample',
    role => 'WebSite Owner',
    email => 'e.xample@example.com',
    phonecc => '44',
    phoneac => '020',
    phonen => '9460234',
    address1 => '1 High Street',
    city => 'MyTown',
    state => 'London',
    postcode => 'SW1 4AA',
    country => 'GB'
  };

  my $t = $a;

  my %result = $t->order( product => $product,
                          csr => $csr,
                          period => 12,
                          approver => 'admin@example.com',
                          insurance => 0,
                          servercount => 1,
                          admin => $a,
                          techusereseller => 1,
                          novalidation => 0
                          );

  my $status = $t->status( orderid => $id );

=head1 DESCRIPTION

Perl module for ordering SSL certificates from Trustico.

=head1 METHODS

=head2 new

Initiates the module. 

Parameters:

username    - your Trustico reseller account username

password    - the password for your reseller account.

=head2 hello

Tests the connection to the Trustico API by sending a string of text and
testing that the same string is returned.

This function returns true if the connection is OK or false if not.

You can call this method with a string of your own or no parameters. If
no parameters are passed a standard string is used to test the connection.

=head2 order

Submits an order to the Trustico API and returns a hash reference 
confirming order details on success or undef.

Parameters:

product     - the product code for the relevant product as provided by
              the products() method.

csr         - the CSR for the certificate

period      - period for the certificate in months. Valid options are
              detailed in the details provided by the products() method.

approver    - Approver email address. Must be one of admin, administrator
              hostmaster, root, webmaster or postmaster prepended to the
              domain supplied in the request

insurance   - Re-issue insurance required - 1 or 0

servercount - Number of server licenses requires. 

novalidation- If set to 1 the CSR can be blank to be provded later via the
              Trustico reseller management interface.

special     - Special instructions to issuer. Up to 255 characters

admin       - Admin contact details hash ref

tech        - Tech contact details hash ref

org         - Organisation details hash ref (required for products with 
              ORG vetting type only - will be ignored if not required)

Tech contact hash ref must contain either the following fields:

    title, firstname, lastname, organisation, email, phonecc, phoneac, 
    phonen, address1, city, state, postcode, country.

The tech contact may also contain an optional address2 field

Alternatively the tech contact may be omitted if the techusereseller
field is set to 1 in which case the default details provided via the 
Trustico reseller control panel will be used.

Admin contact hash must contain all of the fields required for the Tech
contact plus a role field.

The admin contact may also contain the following optional fields:

    taxid, memdate (ISO format)

=head2 status

Gets the status of the order specified by the orderid parameter.

The returned details are in a hash reference.

=head2 products

Returns a hash containing a list of product codes and the details for each
product.

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
    return undef unless $res->{TextToEcho} eq $string;
    return 1;
}

sub order {
    my ($self, %args) = @_;

    my $args = { };
    my $command = 'ProcessType1';
    if ( $products{$args{product}->{process}} != 1 ) {
        $command = 'ProcessType2';
    }

    # XXX process %args into correct fields for $command
    
    my $res = $self->_req($command, $args);
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

    $self->_req('GetStatus', $args);
}

sub products { return %products; }

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

    croak $rv{Error} if $rv{SuccessCode} == 0;
    delete $rv{$_} for (qw/Error SuccessCode/);

    return \%rv;
}

1;
