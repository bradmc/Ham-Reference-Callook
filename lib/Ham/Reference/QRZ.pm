package Ham::Reference::QRZ;

# --------------------------------------------------------------------------
# Ham::Reference::QRZ - An interface to the QRZ XML Database Service
#
# Copyright (c) 2008-2009 Brad McConahay N8QQ.  All rights reserved.
# Cincinnati, Ohio USA
# --------------------------------------------------------------------------

use strict;
use warnings;
use XML::Simple;
use LWP::UserAgent;
use vars qw($VERSION);

our $VERSION = '0.02';

my $qrz_url = "http://online.qrz.com";
my $site_name = 'QRZ XML Database Service';
my $default_timeout = 10;

sub new
{
	my $class = shift;
	my %args = @_;
	my $self = {};
	bless $self, $class;
	$self->_set_agent;
	$self->set_timeout($args{timeout});
	$self->set_callsign($args{callsign}) if $args{callsign};
	$self->set_username($args{username}) if $args{username};
	$self->set_password($args{password}) if $args{password};
	$self->set_key($args{key}) if $args{key};
	return $self;
}

sub login
{
	my $self = shift;
	my $url = "$qrz_url/bin/xml?username=$self->{_username};password=$self->{_password};agent=$self->{_agent}";
	my $login = $self->_get_xml($url);
	if ($login->{Session}->{Error}) {
		$self->{is_error} = 1;
		$self->{error_message} = $login->{Session}->{Error};
		return undef;
	} elsif (!$login->{Session}->{Key}) {
		$self->{is_error} = 1;
		$self->{error_message} = "Unknown Error - Could not retrieve session key";
		return undef;
	} else {
		$self->set_key($login->{Session}->{Key});
		$self->{_session} = $login->{Session};
	}
}

sub set_callsign
{
	my $self = shift;
	my $callsign = shift;
	$callsign =~ tr/a-z/A-Z/;
	$self->{_callsign} = $callsign;
	$self->{_listing} = {};
	$self->{_bio} = {};
}

sub set_username
{
	my $self = shift;
	my $username = shift;
	$self->{_username} = $username;
}

sub set_password
{
	my $self = shift;
	my $password = shift;
	$self->{_password} = $password;
}

sub set_key
{
	my $self = shift;
	my $key = shift;
	$self->{_key} = $key;
}

sub set_timeout
{
	my $self = shift;
	my $timeout = shift || $default_timeout;
	$self->{_timeout} = $timeout;
}

sub get_listing
{
	my $self = shift;
	return $self->{_listing} if $self->{_listing}->{call};
	if (!$self->{_callsign}) {
		$self->{is_error} = 1;
		$self->{error_message} = "Can not get data without a callsign";
		return undef;
	}	
	if (!$self->{_key}) {
		$self->login;
	}
	my $url = "$qrz_url/bin/xml?s=$self->{_key};callsign=$self->{_callsign}";
	my $listing = $self->_get_xml($url);
	if ($listing->{Session}->{Error}) {
		$self->{is_error} = 1;
		$self->{error_message} = $listing->{Session}->{Error};
		return undef;
	}
	$self->{_session} = $listing->{Session};
	$self->{_listing} = $listing->{Callsign};
}

sub get_bio
{
	my $self = shift;
	return $self->{_bio} if $self->{_bio}->{call};
	if (!$self->{_callsign}) {
		$self->{is_error} = 1;
		$self->{error_message} = "Can not get data without a callsign";
		return undef;
	}	
	if (!$self->{_key}) {
		$self->login;
	}
	my $url = "$qrz_url/bin/xml?s=$self->{_key};bio=$self->{_callsign}";
	my $bio = $self->_get_xml($url);
	if ($bio->{Session}->{Error}) {
		$self->{is_error} = 1;
		$self->{error_message} = $bio->{Session}->{Error};
		return undef;
	}
	$self->{_session} = $bio->{Session};
	$self->{_bio} = $bio->{Bio};
}

sub get_session
{
	my $self = shift;
	return $self->{_session};
}


sub is_error { my $self = shift; $self->{is_error} }
sub error_message { my $self = shift; $self->{error_message} }


# -----------------------
#	PRIVATE
# -----------------------

sub _set_agent
{
	my $self = shift;
	$self->{_agent} = "Ham-Reference-QRZ-$VERSION";
}

sub _get_xml
{
	my $self = shift;
	my $url = shift;
	my $ua = LWP::UserAgent->new( timeout=>$self->{_timeout} );
	$ua->agent( $self->{_agent} );
	my $request = HTTP::Request->new('GET', $url);
	my $response = $ua->request($request);
	if (!$response->is_success) {
		$self->{is_error} = 1;
		$self->{error_message} = "Could not contact $site_name - ".HTTP::Status::status_message($response->code);
		return undef;
	}
	my $content = $response->content;
	chomp $content;
	$content =~ s/(\r|\n)//g;

	$content =~ s/iso8859-1/iso-8859-1/; # added to account for what appears to be an
                                         # incorrect encoding declearation string, 2009-10-31 bam

	my $xs = XML::Simple->new( SuppressEmpty => 0 );
	my $data = $xs->XMLin($content);
	return $data;
}

1;
__END__

=head1 NAME

Ham::Reference::QRZ - An object oriented front end for the QRZ.COM Amateur Radio callsign database

=head1 VERSION

Version 0.02

=head1 SYNOPSIS

 use Ham::Reference::QRZ;
 use Data::Dumper;

 my $qrz = Ham::Reference::QRZ->new(
   callsign => 'N8QQ',
   username => 'your_username',
   password => 'your_password'
 );

 # get the listing and bio
 my $listing = $qrz->get_listing;
 my $bio = $qrz->get_bio;

 # dump the data to see how it's structured
 print Dumper($listing);
 print Dumper($bio);

 # set a different callsign to look up
 $qrz->set_callsign('W8IRC');

 # get the listing and print some specific info
 $listing = $qrz->get_listing;
 print "Name: $listing->{name}\n";

=head1 DESCRIPTION

The C<Ham::Reference::QRZ> module provides an easy object oriented front end to access Amateur Radio
callsign data from the QRZ.COM online database.

This module uses the QRZ XML Database Service, which requires a subscription from QRZ.COM.

The QRZ XML Database Service specification states "The data supplied by the XML port may
be extended in a forwardly compatible manner. New XML elements and database objects
(with their associated elements) may be transmitted at any time. It is the developers
responsibility to have their program ignore any unrecognized objects and/or elements
without raising an error, so long as the information received consists of properly formatted XML."

Therefore, this module will not attempt to list or manage individual elements of a callsign.  You
will need to inspect the hash reference keys to see which elements are available for any given
callsign.

This module does not handle any management of reusing session keys at this time.

=head1 CONSTRUCTOR

=head2 new()

 Usage    : my $qrz = Ham::Reference::QRZ->new;
 Function : creates a new Ham::Reference::QRZ object
 Returns  : a Ham::Reference::QRZ object
 Args     : a hash:

            key       required?   value
            -------   ---------   -----
            timeout   no          an integer of seconds to wait for
                                   the timeout of the xml site
                                   default = 10
            callsign  no          you may specify a callsign to look up
                                   here, or you may do it later with the
                                   set_callsign() method
            username  no          you may specify a username to log in with
                                   here, or you may do it later with the
                                   set_username() method
            password  no          you may specify a password to log in with
                                   here, or you may do it later with the
                                   set_password() method
            key       no          set a session key here if you have a valid key so
                                   that no time is wasted doing another login. only
                                   useful if you are managing the reuse of your own keys

=head1 METHODS

=head2 set_callsign()

 Usage    : $qrz->set_callsign( $callsign );
 Function : set the callsign to look up at QRZ
 Returns  : n/a
 Args     : a case-insensitive string containing an Amateur Radio callsign.
 Notes    : calling this will reset the listing and bio data to null until
            you do another get_listing() or get_bio(), respectively.

=head2 set_username()

 Usage    : $qrz->set_username( $username );
 Function : set the username for your QRZ subscriber login
 Returns  : n/a
 Args     : a string

=head2 set_password()

 Usage    : $qrz->set_password( $password );
 Function : set the password for your QRZ subscriber login
 Returns  : n/a
 Args     : a string

=head2 set_key()

 Usage    : $qrz->set_key( $session_key );
 Function : set a session key for retrieving data at QRZ
 Returns  : n/a
 Args     : a string
 Notes    : this is useful only if you already have a valid key before the first login
            during a particular instance of the module.

=head2 set_timeout()

 Usage    : $qrz->set_timeout( $seconds );
 Function : sets the number of seconds to wait on the xml server before timing out
 Returns  : n/a
 Args     : an integer

=head2 get_listing()

 Usage    : $hashref = $qrz->get_listing;
 Function : retrieves data for the standard listing of a callsign from QRZ
 Returns  : a hash reference
 Args     : n/a
 Notes    : if a session key has not already been set, this method will automatically login.
            if a there is already listing information set from a previous lookup,
            this will just return that data.  do a new set_callsign() if you need to refresh
            the data with a new call to the qrz database.

=head2 get_bio()

 Usage    : $hashref = $qrz->get_bio;
 Function : retrieves data for the biography of a callsign from QRZ
 Returns  : a hash reference
 Args     : n/a
 Notes    : if a session key has not already been set, this method will automatically login.
            if a there is already biographical information set from a previous lookup,
            this will just return that data.  do a new set_callsign() if you need to refresh
            the data with a new call to the qrz database.

=head2 login()

 Usage    : $session = $qrz->login;
 Function : initiates a login to the QRZ xml server
 Returns  : a hash reference of the session data
 Args     : n/a
 Notes    : this generally shouldn't need to be used since the get_listing() and get_bio()
            methods will automatically initiate a login to the server if it hasn't already
            been done.

=head2 get_session()

 Usage    : $session = $qrz->get_session;
 Function : retrieves the session information from the most recent call to the XML site
 Returns  : a hash reference of the session data
 Args     : n/a

=head2 is_error()

 Usage    : if ( $qrz->is_error )
 Function : test for an error if one was returned from the call to the XML site
 Returns  : a true value if there has been an error
 Args     : n/a

=head2 error_message()

 Usage    : my $err_msg = $qrz->error_message;
 Function : if there was an error message when trying to call the XML site, this is it
 Returns  : a string (the error message)
 Args     : n/a

=head1 DEPENDENCIES

=over 4

=item * L<XML::Simple>

=item * L<LWP::UserAgent>

=item * An Internet connection

=item * A QRZ.COM subscription that includes access to the QRZ XML Database Service

=back

=head1 TODO

=over 4

=item * Improve error checking and handling.

=item * Session key reuse between instances (maybe).

=item * Look into any possible needed escaping, filtering, etc.

=back

=head1 ACKNOWLEDGEMENTS

This module accesses data from the widely popular QRZ.COM Database.  See http://www.qrz.com

=head1 SEE ALSO

=over 4

=item

In order to use this module you need to have a subscription for the QRZ XML Database Service.
See http://online.qrz.com

=item

The technical reference for the QRZ XML Database Service is at http://online.qrz.com/specifications.html

=back

=head1 AUTHOR

Brad McConahay N8QQ, C<< <brad at n8qq.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2008-2009 Brad McConahay N8QQ, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

