package POE::Component::SmokeBox::Uploads::Rsync;

# ABSTRACT: Obtain uploaded CPAN modules via rsync

# Import what we need from the POE namespace
use POE;
use POE::Component::Generic;
use parent 'POE::Session::AttributeBased'; # TODO do we really need to prereq 0.09?

# The misc stuff we will use
use File::Spec;

# TODO argh, we need to fool Test::Apocalypse::Dependencies!
if ( 0 ) {
	require File::Rsync;
}

# Set some constants
BEGIN {
	if ( ! defined &DEBUG ) { *DEBUG = sub () { 0 } }
}

# starts the component!
sub spawn {
	my $class = shift;

	# The options hash
	my %opt;

	# Support passing in a hash ref or a regular hash
	if ( ( @_ & 1 ) and ref $_[0] and ref( $_[0] ) eq 'HASH' ) {
		%opt = %{ $_[0] };
	} else {
		# Sanity checking
		if ( @_ & 1 ) {
			warn __PACKAGE__ . ' requires an even number of options passed to spawn()';
			return 0;
		}

		%opt = @_;
	}

	# lowercase keys
	%opt = map { lc($_) => $opt{$_} } keys %opt;

	# Should we rsync the entire CPAN or just the authors directory?
	if ( ! exists $opt{'rsync_all'} or ! defined $opt{'rsync_all'} ) {
		if ( DEBUG ) {
			warn 'Using default RSYNC_ALL = 0';
		}

		$opt{'rsync_all'} = 0;
	} else {
		# booleanize it
		$opt{'rsync_all'} = $opt{'rsync_all'} ? 1 : 0;
	}

	# setup the rsync server
	if ( ! exists $opt{'rsync_src'} or ! defined $opt{'rsync_src'} ) {
		if ( DEBUG ) {
			warn 'The argument RSYNC_SRC is missing!';
		}
		return 0;
	} else {
		# TODO should we verify it's a valid rsync path?
		# i.e. 'cpan.cpantesters.org::cpan'

		# Append the authors/id directory
		if ( ! $opt{'rsync_all'} ) {
			if ( $opt{'rsync_src'} !~ m|authors/id$| ) {
				if ( $opt{'rsync_src'} =~ m|/$| ) {
					$opt{'rsync_src'} .= 'authors/id';
				} else {
					$opt{'rsync_src'} .= '/authors/id';
				}
			}
		}
	}

	# Setup the rsync local destination
	# Append the authors directory ( rsync will sync into id automatically )
	# If we appended "authors/id" then rsync will create a local authors/id/id directory!$!@%#$
	if ( ! exists $opt{'rsync_dst'} or ! defined $opt{'rsync_dst'} ) {
		my $dir;
		if ( ! $opt{'rsync_all'} ) {
			$dir = File::Spec->catdir( $ENV{HOME}, 'CPAN', 'authors' );
		} else {
			$dir = File::Spec->catdir( $ENV{HOME}, 'CPAN' );
		}

		if ( DEBUG ) {
			warn 'Using default RSYNC_DST = ' . $dir;
		}

		# Set the default
		$opt{'rsync_dst'} = $dir;
	} else {
		if ( ! $opt{'rsync_all'} ) {
			if ( $opt{'rsync_dst'} !~ /authors$/ ) {
				$opt{'rsync_dst'} = File::Spec->catdir( $opt{'rsync_dst'}, 'authors' );
			}
		}
	}

	# validate the dst path
	if ( ! -d $opt{'rsync_dst'} ) {
		warn "The RSYNC_DST path does not exist ($opt{'rsync_dst'}), please make sure it is a writable directory!";
		return 0;
	}

	# setup the RSYNC opts
	if ( ! exists $opt{'rsync'} or ! defined $opt{'rsync'} ) {
		if ( DEBUG ) {
			warn 'Using default RSYNC = { archive=>1, compress=>1, omit-dir-times=>1, itemize-changes=>1, timeout=>600, contimeout=>120, literal=[ --no-motd ] }';
		}

		# Set the default
		$opt{'rsync'} = {};
	} else {
		if ( ref( $opt{'rsync'} ) ne 'HASH' ) {
			warn "The RSYNC argument is not a valid HASH reference!";
			return 0;
		}
	}

	# Cleanup the rsync opts
	$opt{'rsync'} = {
		'omit-dir-times'	=> 1,
		'archive'		=> 1,
		'compress'		=> 1,
		'itemize-changes'	=> 1,
		'timeout'		=> 10 * 60,	# 10min
		'contimeout'		=> 2 * 60,	# 2min

		# skip the motd, which just consumes bandwidth ;)
		'literal'		=> [ '--no-motd', ],

		# if we rsync the entire CPAN, we delete files too!
		( $opt{'rsync_all'} ? ( 'delete' => 1 ) : () ),

		# use the provided options
		%{ $opt{'rsync'} },
		( DEBUG ? ( 'debug' => 1 ) : () ),
	};

	# merge rsync_src/dst
	$opt{'rsync'}->{'src'} = delete $opt{'rsync_src'};
	$opt{'rsync'}->{'dst'} = delete $opt{'rsync_dst'};

	# TODO File::Rsync doesn't support contimeout!
	# Ticket here: https://rt.cpan.org/Ticket/Display.html?id=67076
	push( @{ $opt{'rsync'}{'literal'} }, "--contimeout=" . delete $opt{'rsync'}{'contimeout'} );

	# setup the alias
	if ( ! exists $opt{'alias'} or ! defined $opt{'alias'} ) {
		if ( DEBUG ) {
			warn 'Using default ALIAS = SmokeBox-Rsync';
		}

		# Set the default
		$opt{'alias'} = 'SmokeBox-Rsync';
	}

	# Setup the interval in seconds
	if ( ! exists $opt{'interval'} or ! defined $opt{'interval'} ) {
		if ( DEBUG ) {
			warn 'Using default INTERVAL = 3600';
		}

		# set the default
		$opt{'interval'} = 3600;
	} else {
		# verify it's a valid numeric amount
		if ( $opt{'interval'} !~ /^\d+$/ or $opt{'interval'} < 1 ) {
			warn "The INTERVAL argument is not a valid number!";
			return 0;
		}
	}

	# Setup the event
	if ( ! exists $opt{'event'} or ! defined $opt{'event'} ) {
		if ( DEBUG ) {
			warn 'Using default EVENT = upload';
		}

		# set the default
		$opt{'event'} = 'upload';
	}

	# Setup the rsyncdone event
	if ( ! exists $opt{'rsyncdone'} or ! defined $opt{'rsyncdone'} ) {
		if ( DEBUG ) {
			warn 'Using default RSYNCDONE = undef';
		}

		# set the default
		$opt{'rsyncdone'} = undef;
	}

	# Setup the session
	if ( ! exists $opt{'session'} or ! defined $opt{'session'} ) {
		if ( DEBUG ) {
			warn 'Using default SESSION = caller';
		}

		# set the default
		$opt{'session'} = undef;
	} else {
		# eval it because it might already be a regular scalar...
		eval {
			# Convert it to an ID
			if ( $opt{'session'}->isa( 'POE::Session' ) ) {
				$opt{'session'} = $opt{'session'}->ID;
			}
		};
	}

	# Create our session
	POE::Session->create(
		__PACKAGE__->inline_states(),
		'heap'	=>	{
			'ALIAS'		=> $opt{'alias'},
			'RSYNC_OPT'	=> $opt{'rsync'},
			'RSYNC_ALL'	=> $opt{'rsync_all'},
			'INTERVAL'	=> $opt{'interval'},

			'SESSION'	=> $opt{'session'},
			'EVENT'		=> $opt{'event'},
			'RSYNCDONE'	=> $opt{'rsyncdone'},
		},
	);

	# return success
	return 1;
}

# This starts the component
sub _start : State {
	if ( DEBUG ) {
		warn 'Starting alias "' . $_[HEAP]->{'ALIAS'} . '"';
	}

	# Set up the alias for ourself
	$_[KERNEL]->alias_set( $_[HEAP]->{'ALIAS'} );

	# Setup the session
	if ( ! defined $_[HEAP]->{'SESSION'} ) {
		# Use the sender
		if ( $_[KERNEL] == $_[SENDER] ) {
			warn 'Not called from another POE session and SESSION was not set!';
			$_[KERNEL]->yield( 'shutdown' );
			return;
		} else {
			$_[HEAP]->{'SESSION'} = $_[SENDER]->ID;
		}
	}

	# Give it a refcount
	$_[KERNEL]->refcount_increment( $_[HEAP]->{'SESSION'}, __PACKAGE__ );

	# Do the first rsync!
	$_[KERNEL]->yield( '_rsync_start' );

	return;
}

sub _rsync_start : State {
	if ( DEBUG ) {
		warn 'Starting rsync run...';
	}

	$_[HEAP]->{'STARTTIME'} = time;

	# spawn poco-generic
	$_[HEAP]->{'RSYNC'} = POE::Component::Generic->spawn(
		'alt_fork'		=> 1,	# conserve memory by using exec
		'package'		=> 'File::Rsync',
		'methods'		=> [ qw( exec status out err ) ],

		'object_options'	=> [ %{ $_[HEAP]->{'RSYNC_OPT'} } ],
		'alias'			=> $_[HEAP]->{'ALIAS'} . '-' . 'Generic',

		( DEBUG ? ( 'debug' => 1, 'error' => '_rsync_generic_error' ) : () ),
	);

	# tell poco-generic to do it!
	$_[HEAP]->{'RSYNC'}->exec( { 'event' => '_rsync_exec_result' } );

	return;
}

sub _rsync_exec_result : State {
	my( $ref, $result ) = @_[ARG0, ARG1];

	if ( DEBUG ) {
		warn "Rsync exec result: $result";
	}

	# Was it successful?
	if ( $result ) {
		# Get the stdout listing so we can parse it for uploaded files
		$_[HEAP]->{'RSYNC'}->out( { 'event' => '_rsync_out_result' } );
	} else {
		# Get the exit code
		$_[HEAP]->{'RSYNC'}->status( { 'event' => '_rsync_status_result' } );
	}

	return;
}

sub _rsync_status_result : State {
	my( $ref, $result ) = @_[ARG0, ARG1];

	# We ignore status 23/24 errors, it happens occassionally...
	if ( $result == 23 or $result == 24 ) {
		if ( DEBUG ) {
			warn "Ignoring Rsync status $result error...";
		}

		# Get the stdout listing so we can parse it for uploaded files
		$_[HEAP]->{'RSYNC'}->out( { 'event' => '_rsync_out_result' } );
	} else {
		if ( DEBUG ) {
			warn "Rsync exec error - status: $result";
			$_[HEAP]->{'RSYNC'}->err( { 'event' => '_rsync_err_result' } );
		} else {
			# We're done with the rsync subprocess, shut it down!
			$_[KERNEL]->post( $_[HEAP]->{'RSYNC'}->session_id, 'shutdown' );
			undef $_[HEAP]->{'RSYNC'};
		}

		# Let the session know the run is done
		if ( defined $_[HEAP]->{'RSYNCDONE'} ) {
			$_[KERNEL]->post( $_[HEAP]->{'SESSION'}, $_[HEAP]->{'RSYNCDONE'}, {
				'status'	=> 0,
				'exit'		=> $result,
				'exit_str'	=> rsync_exit_string( $result ),
				'starttime'	=> $_[HEAP]->{'STARTTIME'},
				'stoptime'	=> time,
				'dists'		=> 0,
			} );
		}

		# Do another run in INTERVAL
		$_[KERNEL]->delay_set( '_rsync_start' => $_[HEAP]->{'INTERVAL'} );
	}

	return;
}

sub _rsync_err_result : State {
	my( $ref, $result ) = @_[ARG0, ARG1];

	warn "Got rsync STDERR:";
	warn $_ for @$result;

	# We're done with the rsync subprocess, shut it down!
	$_[KERNEL]->post( $_[HEAP]->{'RSYNC'}->session_id, 'shutdown' );
	undef $_[HEAP]->{'RSYNC'};

	return;
}

sub _rsync_out_result : State {
	my( $ref, $result ) = @_[ARG0, ARG1];

	# We're done with the rsync subprocess, shut it down!
	$_[KERNEL]->post( $_[HEAP]->{'RSYNC'}->session_id, 'shutdown' );
	undef $_[HEAP]->{'RSYNC'};

	# Parse the result, and inform the session of new uploads!
	# Look at the rsync man page for details on the itemize-changes format
	# >f.st...... id/R/RC/RCAPUTO/CHECKSUMS
	# >f.st...... id/R/RD/RDB/CHECKSUMS
	# >f+++++++++ id/R/RD/RDB/POE-Component-SNMP-1.1004.meta
	# >f+++++++++ id/R/RD/RDB/POE-Component-SNMP-1.1004.readme
	# >f+++++++++ id/R/RD/RDB/POE-Component-SNMP-1.1004.tar.gz
	# >f+++++++++ id/R/RD/RDB/POE-Component-SNMP-1.1005.meta
	# >f+++++++++ id/R/RD/RDB/POE-Component-SNMP-1.1005.readme
	# >f+++++++++ id/R/RD/RDB/POE-Component-SNMP-1.1005.tar.gz
	# >f.st...... id/R/RE/REDICAPS/CHECKSUMS
	my @modules;
	foreach my $l ( @$result ) {
		# file regex taken from POE::Component::SmokeBox::Uploads::NNTP, thanks BinGOs!
		# if RSYNC_ALL is enabled, we rsync from the root - otherwise the id directory
		if ( $l =~ /^\>f\+{9}\s+(?:authors\/)?id\/(\w+\/\w+\/\w+\/.+\.(?:tar\.(?:gz|bz2)|tgz|zip))$/ ) {
			push( @modules, $1 );
		}
	}

	# Let the session know the run is done
	if ( defined $_[HEAP]->{'RSYNCDONE'} ) {
		$_[KERNEL]->post( $_[HEAP]->{'SESSION'}, $_[HEAP]->{'RSYNCDONE'}, {
			'status'	=> 1,
			'exit'		=> 0,
			'exit_str'	=> rsync_exit_string( 0 ),
			'starttime'	=> $_[HEAP]->{'STARTTIME'},
			'stoptime'	=> time,
			'dists'		=> scalar @modules,
		} );
	}

	# send off the modules
	foreach my $m ( @modules ) {
		$_[KERNEL]->post( $_[HEAP]->{'SESSION'}, $_[HEAP]->{'EVENT'}, $m );
	}

	# Do another run in INTERVAL
	$_[KERNEL]->delay_set( '_rsync_start' => $_[HEAP]->{'INTERVAL'} );

	return;
}

sub _rsync_generic_error : State {
	my $err = $_[ARG0];

	if( $err->{stderr} ) {
		# $err->{stderr} is a line that was printed to the
		# sub-processes' STDERR.  99% of the time that means from
		# your code.
		warn "Got stderr: $err->{stderr}";
	} else {
		# Wheel error.  See L<POE::Wheel::Run/ErrorEvent>
		# $err->{operation}
		# $err->{errnum}
		# $err->{errstr}
		warn "Got wheel error: $err->{operation} ($err->{errnum}): $err->{errstr}";
	}

	return;
}

# POE Handlers
sub _stop : State {
	if ( DEBUG ) {
		warn 'Stopping alias "' . $_[HEAP]->{'ALIAS'} . '"';
	}

	return;
}

sub _child : State {
	return;
}

sub shutdown : State {
	if ( DEBUG ) {
		warn "Shutting down alias '" . $_[HEAP]->{'ALIAS'} . "'";
	}

	# cleanup some stuff
	$_[KERNEL]->alias_remove( $_[HEAP]->{'ALIAS'} );

	# tell poco-generic to shutdown
	if ( defined $_[HEAP]->{'RSYNC'} ) {
		$_[KERNEL]->call( $_[HEAP]->{'RSYNC'}->session_id, 'shutdown' );
		undef $_[HEAP]->{'RSYNC'};
	}

	# decrement the refcount
	if ( defined $_[HEAP]->{'SESSION'} ) {
		$_[KERNEL]->refcount_decrement( $_[HEAP]->{'SESSION'}, __PACKAGE__ );
	}

	return;
}

{
	# Taken from the rsync v3.0.8 manpage
	my %exitcodes = (
		0  => 'Success',
		1  => 'Syntax or usage error',
		2  => 'Protocol incompatibility',
		3  => 'Errors selecting input/output files, dirs',
		4  => 'Requested action not supported: an attempt was made to manipulate 64-bit files on a platform that cannot support them; or an option was specified that is supported by the client and not by the server.',
		5  => 'Error starting client-server protocol',
		6  => 'Daemon unable to append to log-file',
		10 => 'Error in socket I/O',
		11 => 'Error in file I/O',
		12 => 'Error in rsync protocol data stream',
		13 => 'Errors with program diagnostics',
		14 => 'Error in IPC code',
		20 => 'Received SIGUSR1 or SIGINT',
		21 => 'Some error returned by waitpid()',
		22 => 'Error allocating core memory buffers',
		23 => 'Partial transfer due to error',
		24 => 'Partial transfer due to vanished source files',
		25 => 'The --max-delete limit stopped deletions',
		30 => 'Timeout in data send/receive',
		35 => 'Timeout waiting for daemon connection',
	);

	sub rsync_exit_string {
		return $exitcodes{ $_[0] };
	}
}

1;

=pod

=for stopwords ARG admin crontabbed dists rsyncdone BinGOs

=for Pod::Coverage DEBUG rsync_exit_string

=head1 SYNOPSIS

	#!/usr/bin/perl
	use strict; use warnings;

	use POE;
	use POE::Component::SmokeBox::Uploads::Rsync;

	# Create our session to receive events from rsync
	POE::Session->create(
		package_states => [
			'main' => [qw(_start upload)],
		],
	);

	sub _start {
		# Tell the poco to start it's stuff!
		POE::Component::SmokeBox::Uploads::Rsync->spawn(
			# thanks to DAGOLDEN for allowing us to use his mirror!
			'rsync_src'	=> 'cpan.dagolden.com::CPAN',
		) or die "Unable to spawn the poco-rsync!";

		return;
	}

	sub upload {
		print $_[ARG0], "\n";
		return;
	}

	POE::Kernel->run;

=head1 DESCRIPTION

POE::Component::SmokeBox::Uploads::Rsync is a POE component that alerts newly uploaded CPAN distributions. It obtains this information by
running rsync against a CPAN mirror. This effectively keeps your local CPAN mirror up-to-date too! This is only for the C<CPAN/authors/id>
directory, to make it easier on the rsync process. If you want to keep your entire mirror up-to-date, please use your normal
( crontabbed? ) rsync script and tell it to exclude the C<authors/id> directory to prevent missed uploads.

Really, all you have to do is load the module and call it's spawn() method:

	use POE::Component::SmokeBox::Uploads::Rsync;
	POE::Component::SmokeBox::Uploads::Rsync->spawn( ... );

This method will return failure on errors or return success. Normally you just need to set the rsync server. ( rsync_src )

=head2 spawn()

This constructor accepts either a hashref or a hash, valid options are:

=head3 alias

This sets the alias of the session.

The default is: SmokeBox-Rsync

=head3 rsync_src

This sets the rsync source ( the server you will be mirroring from ) and it is a mandatory parameter. For a list of valid rsync mirrors, please
consult the L<http://www.cpan.org/SITES.html> mirror list.

The default is: undefined

This component will automatically append '/authors/id' to the src, please don't add it yourself. ( if L</rsync_all> == 0 )

=head3 rsync_dst

This sets the local rsync destination ( where your local CPAN mirror resides )

The default is: $ENV{HOME}/CPAN

This component will automatically append '/authors' to the dst, please don't add it yourself. ( if L</rsync_all> == 0 )

=head3 rsync_all

If this is a true value, this module will rsync the entire CPAN. Useful for lazy people who don't want to run a separate rsync process
for the rest of CPAN. If it is false, this module will rsync only the authors/id directory to make the rsync run faster.

Additionally, if this is true the option C<--delete> will be passed to the rsync process. This keeps your local copy exactly the same as it
is on CPAN. If you want to override this just pass a delete=0 option to the L</rsync> hash.

The default is: false

=head3 rsync

This sets the rsync options. Normally you do not need to touch this, but if you do - please be aware that your options clobbers the default
values! Please look at the L<File::Rsync> manpage for the options. Again, touch this if you know what you are doing!

The default is:

	{
		archive 	=> 1,
		compress 	=> 1,
		omit-dir-times	=> 1,
		itemize-changes	=> 1,
		timeout		=> 10 * 60,	# 10min
		contimeout	=> 2 * 60,	# 2min
		literal 	=> [ qw( --no-motd ) ],
	}

NOTE: The usage of "omit-dir-times/itemize-changes/contimeout" means you need a rsync newer than v3.0.0!

=head3 interval

This sets the seconds between rsync mirror executions. Please don't set it to a low value unless you have permission from the mirror admin!

The default is: 3600 ( 1 hour )

=head3 event

This sets the event which will receive notification about uploaded dists. It will receive one argument in ARG0, which is a single string. An
example is:

	V/VP/VPIT/CPANPLUS-Dist-Gentoo-0.07.tar.gz

The default is: upload

=head3 session

This sets the session which will receive the notification event. You can either use a POE session id, alias, or reference. You can just spawn
the component inside another session and it will automatically receive the notifications.

The default is: undef ( caller session )

=head3 rsyncdone

This sets an additional event when the rsync process is done executing. It will receive a hashref in ARG0 which details some information. An
example is:

	{
		'status'	=> 1,		# boolean value whether the rsync run was successful or not
		'exit'		=> 0,		# exit code of the rsync process, useful to look up rsync errors ( already bit-shifted! )
		'exit_str'	=> 'Success',	# stringified exit code of the rsync process
		'starttime'	=> 1260432932,	# self-explanatory
		'stoptime'	=> 1260432965,	# self-explanatory
		'dists'		=> 7,		# number of new distributions uploaded to CPAN
	}

NOTE: In my testing sometimes rsync throws an exit code of 23 ( Partial transfer due to error ) or 24 ( Partial transfer due to vanished source
files ), this module automatically treats them as "success" and sets the exit code to 0. This is caused by the intricacies of rsync trying to
mirror some forbidden files and deletions on the host. See L<https://bugzilla.samba.org/show_bug.cgi?id=3653> for more info.

The default is: undef ( not enabled )

=head2 Commands

There is only one command you can use, as this is a very simple module.

=head3 shutdown

Tells this module to shut down the underlying rsync session and terminate itself.

	$_[KERNEL]->post( 'SmokeBox-Rsync', 'shutdown' );

=head2 Module Notes

You can enable debugging mode by doing this:

	sub POE::Component::SmokeBox::Uploads::Rsync::DEBUG () { 1 }
	use POE::Component::SmokeBox::Uploads::Rsync;

=head1 SEE ALSO
POE::Component::SmokeBox
File::Rsync

=cut
