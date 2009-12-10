#!/usr/bin/perl
use strict; use warnings;

#sub POE::Component::SmokeBox::Uploads::Rsync::DEBUG () { 1 }

use POE;
use POE::Component::SmokeBox::Uploads::Rsync;

use Time::Duration qw( duration_exact );

# Create our session to receive events from rsync
POE::Session->create(
	package_states => [
		'main' => [qw(_start upload rsyncdone)],
	],
);

sub _start {
	# Tell the poco to start it's stuff!
	POE::Component::SmokeBox::Uploads::Rsync->spawn(
		# thanks to DAGOLDEN for allowing us to use his mirror!
		'rsync_src'	=> 'cpan.dagolden.com::CPAN',
		'rsyncdone'	=> 'rsyncdone',
	) or die "Unable to spawn the poco-rsync!";

	return;
}

sub rsyncdone {
	my $r = $_[ARG0];

	if ( $r->{'status'} ) {
		print "Successfully completed a rsync run! (duration: " . duration_exact( $r->{'stoptime'} - $r->{'starttime'} ) . " dists: $r->{'dists'})\n";
	} else {
		print "Failed to complete a rsync run: rsync error $r->{'exit'} duration: " . duration_exact( $r->{'stoptime'} - $r->{'starttime'} ) . "\n";
	}

	return;
}

sub upload {
	print $_[ARG0], "\n";
	return;
}

POE::Kernel->run;
