# Build.PL
use strict; use warnings;
use Module::Build;

my $build = Module::Build->new(
	# look up Module::Build::API for the info!
	'dynamic_config'	=> 0,
	'module_name'		=> 'POE::Component::SmokeBox::Uploads::Rsync',
	'license'		=> 'perl',

	'dist_abstract'		=> "Obtain uploaded CPAN modules via rsync",
	'dist_author'		=> 'Apocalypse <APOCAL@cpan.org>',

	'create_packlist'	=> 1,
	'create_makefile_pl'	=> 'traditional',
	'create_readme'		=> 1,
	'create_license'	=> 1,
	'sign'			=> 0,

	'test_files'		=> 't/*.t',

	'add_to_cleanup'	=> [ 'META.yml', 'Makefile.PL', 'README', 'Makefile', 'LICENSE' ], # automatically generated

	'requires'		=> {
		# POE Stuff
		'POE'				=> 0,
		'POE::Session::AttributeBased'	=> 0,
		'POE::Component::Generic'	=> 0,

		# The actual rsync stuff
		'File::Rsync'			=> 0,
		'File::Spec'			=> 0,

		# we need a recent perl
		'perl'				=> '5.008',
	},

	# include the standard stuff in META.yml
	'meta_merge'	=> {
		'resources'	=> {
			'license'	=> 'http://dev.perl.org/licenses/',
			'homepage'	=> 'http://search.cpan.org/dist/POE-Component-SmokeBox-Uploads-Rsync',
			'bugtracker'	=> 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-SmokeBox-Uploads-Rsync',
			'repository'	=> 'http://github.com/apocalypse/perl-poe-smokebox-uploads-rsync',
		},
	},
);

# all done!
$build->create_build_script;
