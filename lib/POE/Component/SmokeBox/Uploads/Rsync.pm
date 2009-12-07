# Declare our package
package POE::Component::SmokeBox::Uploads::Rsync;
use strict; use warnings;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

# Import what we need from the POE namespace
use POE;
use POE::Component::Generic;
use base 'POE::Session::AttributeBased';

# The rsync stuff we will use
#use File::Rsync;	# only loaded in the poco-generic subprocess

1;
__END__

=for stopwords POE

=head1 NAME

POE::Component::SmokeBox::Uploads::Rsync - Obtain uploaded CPAN modules via rsync

=head1 SYNOPSIS


=head1 ABSTRACT

POE::Component::SmokeBox::Uploads::Rsync is a POE component that alerts newly uploaded CPAN distributions. It obtains this information by
running rsync against a CPAN mirror. This effectively keeps your local CPAN mirror up-to-date too!

=head1 DESCRIPTION

=head1 EXPORT

None.

=head1 SEE ALSO

L<POE::Component::SmokeBox>

L<File::Rsync>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::SmokeBox::Uploads::Rsync

=head2 Websites

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-SmokeBox-Uploads-Rsync>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-SmokeBox-Uploads-Rsync>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-SmokeBox-Uploads-Rsync>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-SmokeBox-Uploads-Rsync>

=item * CPAN Testing Service

L<http://cpants.perl.org/dist/overview/POE-Component-SmokeBox-Uploads-Rsync>

=back

=head2 Bugs

Please report any bugs or feature requests to C<poe-component-smokebox-uploads-rsync at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-SmokeBox-Uploads-Rsync>.  I will be
notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
