package Image::Maps::Plot::FromPostcode; # where in the world are London.pm members?

our $VERSION = 1.0;
our $DATE = "Mon 28 May 09:59 2002 CET"; #"Fri 06 July 19:18 2001 BST";
use 5.006;
use strict;
use warnings;
use GD;
use File::Basename;
use Data::Dumper;
use WWW::MapBlast 0.02;
use Image::GD::Thumbnail 0.011;

=head1 NAME

Image::Maps::Plot::FromPostcode - plots postcodes on world/regional map images/HTML

=head1 SYNOPSIS

	use Image::Maps::Plot::FromPostcode;

	# Create a single map

	new Image::Maps::Plot::FromPostcode (MAP=>"THE WORLD","PATH"=>"E:/src/pl/out.html");

	# Create all possible maps

	Image::Maps::Plot::FromPostcode::all("E:/src/pl/");

	# Add a user to the db

	Image::Maps::Plot::FromPostcode::load_db (".earth.dat");
	Image::Maps::Plot::FromPostcode::add_entry ('Peter Smith','United Kingdom','BS7 29JT');
	Image::Maps::Plot::FromPostcode::save_db (".london.pm.dat");

	__END__

=head1 DESCRIPTION

Plots postcode-defined points on JPEG maps, and creates an HTML page with an image map to display the image.

I was bored and got this message on a list:

	From: london.pm-admin@london.pm.org
	[mailto:london.pm-admin@london.pm.org]On Behalf Of Philip Newton
	Sent: 21 June 2001 11:44
	To: 'london.pm@london.pm.org'
	Subject: Re: headers

	Simon Wistow wrote:
	> It's more a collection of people who have the common connection
	> that they live and london and like perl.
	> In fact neither of those actually have to be true since I personally
	> know two people on the list who don't program Perl and one of whom
	> doesn't even live in London.

	How many off-London people have we got? (Well, also excluding people who
	live near London.)

	From outside the UK, there's Damian, dha, Paul M, I; Lucy and lathos
	probably also qualify as far as I can tell. Marcel used to work in London
	(don't know whether he still does). Anyone else?

	Cheers,
	Philip
	--
	Philip Newton <Philip.Newton@datenrevision.de>
	All opinions are my own, not my employer's.
	If you're not part of the solution, you're part of the precipitate.

In the twenty-second weekly summary of the London Perl Mongers
mailing list, for the week starting 2001-06-18:

	In other news: ... a london.pm world map ...

Hence the module.

=head1 PREREQUISITES

	Data::Dumper;
	File::Basename;
	GD;
	strict;
	warnings.
	WWW::MapBlast 0.02
	Image::GD::Thumbnail 0.011

=head1 DISTRIBUTION CONTENTS

In addition to this file, the distribution relies upon the included files:

	.earth.dat
	london_postcodes.jpg
	uk.jpg
	world.jpg

=head1 EXPORTS

None.  They're dirty dirty dirty.

=head1 CAVEATS

The exmaple map, london_postcodes.jpg, is inaccurate.

Whilst degrees of latitude are accurate to two decimal places, Degrees of
longitude are taken to be 69 miles.  This will be adjusted in a later version.

All images must be JPEGs - PNG or other support could easily be added.

=cut

#
# Global scalars
#
our $chat = 0;					# Real-time output of what's going on; affecting by L<"new">.
our $ADDENTRY = 'MULTIPLE';		# Cf. L<"add_entry">
our %locations = ();			# Cf. L<"load_db">

#
# See L<NOTES ON LATITUDE AND LONGITUDE> and sub _make_latlon
#
our @LAT;
our @_LAT = (
	68.70, 	68.71,	68.73,	68.75,	68.79,	68.83,	68.88,	68.94,	68.99,
	69.05,	69.12,	69.18,	69.23,	69.28,	69.32,	69.36,	69.39,	69.40,	69.41
);
our @LON;
our @_LON = (
	69.17,	68.91,	68.13,	66.83,	65.03,	62.73,	59.96,	56.73,	53.06,
	49.00,	44.55,	39.77,	34.67,	29.32,	23.73,	17.96,	12.05,	6.05,	0.00,
);
&_make_latlon;

#
# See also L<"ADDING MAPS">.
#
our %MAPS = (
	"THE WORLD" => {
		FILE	  	=> "world.jpg",
		DIM 	  	=> [823,485],
		SPOTSIZE	=> 2,
		ANCHOR_PIXELS => [389,258],		# Zero lat, zero lon
		ANCHOR_LATLON => [0,0],	# 0,0
		ANCHOR_NAME	  => '',
		ANCHOR_PLACE => 'Zero degrees latitude, zero degree longitude',
		ONEMILE 		=> 0.0342,	# was 0.0056, better with 0.0348
	},
	"THE UK" 	=> {
		FILE	  	=> "uk.jpg",
		DIM 	  	=> [363,447],
		SPOTSIZE	=> 4,
		ANCHOR_PIXELS => [305,388],		# Greenwich
		ANCHOR_LATLON => [51.466,0],
		ANCHOR_NAME	  => 'Greenwich',
		ANCHOR_PLACE  => 'Observatory',
		# ONEMILE	=> 00.55,
		ONEMILE	=> 0.51,
	},
	"A BAD MAP OF LONDON LONDON"	=> {
		FILE		=> "london_postcodes.jpg",
		DIM			=> [650,640],
		SPOTSIZE	=> 8,
		ANCHOR_PIXELS => [447,397],		# Greenwich on the pixel map
		ANCHOR_LATLON => [51.466,0],	# Greenwich lat/lon
		ANCHOR_NAME	  => 'Greenwich',
		ANCHOR_PLACE  => 'Observatory',
		ONEMILE		=> 19.5,			# 1 km = .6 miles  (10km=180px = 10miles=108px)
	},

);


=head1 USEAGE METHODS

=head2 new

Not really a constructor, as it does not return a new object of this class, but
does the whole job of loding, creating and saving the files, so maybe it shouldn't
be called new.

Accepts arguments in a hash, where keys/values are as follows:

=over 4

=item MAP

Either C<THE WORLD>, C<THE UK>, C<A BAD MAP OF LONDON>, or any other key to the C<%MAPS> hash
defined elsewhere, and documented L<below|"ADDING MAPS">.

=item PATH

The path at which to save - will use the filename you supply, but please include an extension, coz I'm lazy.
You will receive a C<.jpg> and C<.html> file in return.

=item DBNAME

Name of the configuration/db file - defaults to C<.earth.dat>, which comes
with the distribution.

=item CHAT

Set if you want rabbit on the screen.

=item CREATIONTXT

Text output onto the image.  Defaults to 'Created on <date> by <package>.';

=item TITLE

Title text to include on the image (in bold) and as the content of the HTML page's C<TITLE> element: is appended with the name of the map.  This defaults to C<London.pm>, where this module originates.

=item INCLUDEANCHOR

Set if you wish the map's anchor point to be included in the output.

=item FNPREFIX

Filename prefix - added to the start of all files output except the db file.
Default is C<m_>.

=back

=cut

sub new { my $class = shift;
	die "Please call with a package ID" if not defined $class;
	my %args;
	my $self = {};
	bless $self,$class;

	# Take parameters and place in object slots/set as instance variables
	if (ref $_[0] eq 'HASH'){	%args = %{$_[0]} }
	elsif (not ref $_[0]){		%args = @_ }

	# Default instance variables
	$self->{HTML} 			= '';									# Will contain the HTML for the image and image map
	$self->{MAP}			= "WORLD";								# Default map cf. our %MAPS
	$self->{CREATIONTXT} 	= "Created on ".(scalar localtime)." by ".__PACKAGE__;
	$self->{FNPREFIX} 		= 'm_';
	$self->{INCLUDEANCHOR} 	= 1;
	$self->{TITLE}			= "London.pm";
	$self->{DBNAME}			= ".earth.dat";

	# Overwrite default instance variables with user's values
	foreach (keys %args) {	$self->{uc $_} = $args{$_} }

	&load_db($self->{DBNAME});

	$chat = 1 if exists $self->{CHAT};

	die  "Please supply an output path as parameter PATH\n" if not exists $self->{PATH};
	my ($name,$path,$suffix) = fileparse($self->{PATH},'(\.[^.]*)?$' );
	die  "Please supply a filepath with a dummy extension" if not defined $name;
	$self->{PATH} = $path.$name;
	$self->{IMGPATH} = $name.'.jpg';

	# Try to load the image into our object as a GD object
	die "There is no option for a map of $self->{MAP}" if not exists $MAPS{$self->{MAP}};
	die "No map for $self->{MAP} at " if not -e $MAPS{$self->{MAP}}->{FILE};
	open IN, $MAPS{$self->{MAP}}->{FILE} or die "Could open the $self->{MAP} from $MAPS{$self->{MAP}}->{FILE} ";
	$self->{IM} = GD::Image->newFromJpeg(*IN);
	close IN;
	$self->{SPOTCOLOUR} = $self->{IM}->colorResolve(255,0,0);	# Colour of the spots to be placed on the map

	# Now we have the argument for the map in question:
	$self->_add_html_top;
	$self->_add_map_top;

	# Add the anchor point for author's reference - remove late
	if (exists $self->{INCLUDEANCHOR}){
		my ($x,$y) = _latlon_to_xy(
			$self->{MAP},
			$MAPS{$self->{MAP}}->{ANCHOR_LATLON}[0],
			$MAPS{$self->{MAP}}->{ANCHOR_LATLON}[1]
		);
		if (defined $x and defined $y){
			$self->_add_to_map(
				$x,$y,
				$MAPS{$self->{MAP}}->{ANCHOR_NAME},
				$MAPS{$self->{MAP}}->{ANCHOR_PLACE}
			);
		}
	}

	$self->_populate;
	$self->_add_map_bottom;
	$self->_add_html_bottom;

	$self->_save;
	return 1;
}



=head2 &all (base_path,base_url)

A subroutine, not a method, that produces all available maps, and an index page with thumbnails.

It accepts four arguments, a path at which files can be built,
a filename prefix (see L<"new">), a title, and blurb to add beneath the list of hyperlinks to the maps.

An index page will be produced, linking to the following files for each map:

=over 4

m_C<MAPNAME>.jpg
m_C<MAPNAME>_t.jpg
m_C<MAPNAME>.html

=back

where MAPNAME is ... the name of the map.  The C<m_> prefix is held in the instance variable C<FNPREFIX>.
You may also wish to look at and adjust the instance variable C<CREATIONTXT>.

=cut

sub all { my ($fpath,$fnprefix,$title,$blurb) = (@_);
	die "Please supply a PATH as requeseted in the POD.\n" if not defined $fpath or !-d $fpath;
	if ($fpath !~ /(\/|\\)$/){$fpath.="/";}
	$fnprefix = '' if not defined $fnprefix;
	if (not defined $title) {
		$title = "London.pm";
	}
	if (not defined $blurb) {
		$blurb =
		"These maps were created on ".(scalar localtime)." by ".__PACKAGE__;
		$blurb .=", available on <A href='http://search.cpan.org'>CPAN</A>, from data last updated on $DATE."
		."<P>Maps originate either from the CIA (who placed them in the public domain), or unknown sources (defunct personal pages on the web)."."<BR><HR><P><SMALL>Copyright (C) <A href='mailto:lGoddard\@CPAN.Org'>Lee Goddard</A> 2001 - available under the same terms as Perl itself</SMALL></P>";
	};
	my $self = bless {};
	$self->{HTML} = '';
	$self->_add_html_top("$title Maps Index");
	$self->{HTML} .= "<H1>$title Maps<HR></H1>\n";

	foreach my $map (keys %MAPS){
		$map =~ /(\w+)$/;
		die "Error making filename: didn't match regex" if not defined $1;
		$_ = __PACKAGE__;
		my $mapmaker = new (__PACKAGE__,{MAP=>$map, PATH=>$fpath.$fnprefix.$1});
		my ($tx,$ty) = _create_thumbnail($fpath.$fnprefix.$1);
		$self->{HTML}.="<P><A href='$fnprefix$1.html'>";
		$self->{HTML}.="<IMG src='$fnprefix$1_t.jpg' hspace='12' border='1' width='$tx' height='$ty'>";
		$self->{HTML}.="$1";
		$self->{HTML}.="</A></P>\n";
	}

	$self->{HTML}.="<P>&nbsp;</P>";
	$self->{HTML}.=$blurb;
	$self->_add_html_bottom;
	open OUT,">$fpath$fnprefix"."index.html" or die "Couldn't open <$fpath$fnprefix"."index.html> for writing";
	print OUT $self->{HTML};
	close OUT;
}


#
# Private method _save ($path)
#
# Saves the product of the module.
#
# Accepts a file path at which to save the JPEG and HTML output.
# Supply a filename with any suffix: it will be ignored, and the JPEG image and HTML files will be given C<.jpg> and C<.html>
# suffixes respectively.
#
sub _save { my ($self) = (shift);
	die  "Please call as a method." if not defined $self or not ref $self;
	local (*OUT);

	# Add text to image
	my $title = $self->{TITLE} . ' in '. $self->{MAP};
	my @textlines = split /(by.*)$/,$self->{CREATIONTXT};
	my ($x,$y) = $self->{IM}->getBounds();
	my @bounds;
	$x = 5;
	$y = 17;
	@bounds = $self->{IM}->stringTTF($self->{SPOTCOLOUR},'Verdanal',10,0,$x,1,$title);
	if ($#bounds==-1){
		warn "Apparently no TTF support for Verdana?\n",@$,"\nTrying simpler method....\n" if $chat;
		#gdGiantFont, gdLargeFont, gdMediumBoldFont, gdSmallFont and gdTinyFont
		$self->{IM}->string(gdMediumBoldFont,$x,1,$title,$self->{SPOTCOLOUR});
		for (0..$#textlines){
			$self->{IM}->string(gdSmallFont,$x,$y+($_*11),$textlines[$_],$self->{SPOTCOLOUR});
		}
	} else {
		for (0..$#textlines){
			@bounds = $self->{IM}->stringTTF($self->{SPOTCOLOUR},'Verdanal',8,0,$x,$y+($_*9),$textlines[$_]);
		}
		warn "Used TTF." if $chat;
	}

	#   the JPEG
	warn "Going to save $self->{PATH}.jpg...\n" if $chat;
	open OUT, ">$self->{PATH}.jpg" or die "Could not save to <$self->{PATH}.jpg> ";
	binmode OUT;
	print OUT $self->{IM}->jpeg;
	close OUT;
	# Save the HTML
	warn "Going to save $self->{PATH}.html...\n" if $chat;
	open OUT, ">$self->{PATH}.html" or die "Could not save to <$self->{PATH}.html> ";
	print OUT $self->{HTML};
	close OUT;
	warn "OK.\n" if $chat;
}



# _populate
#
# Populates the current map.
#
sub _populate { my ($self) = (shift);
	die  "Please call as a method." if not defined $self or not ref $self;
	warn "Populating the $self->{MAP} map.\n" if $chat;
	foreach my $pusson (keys %locations){
		warn "\tadding $pusson $locations{$pusson}->{PLACE}\n" if $chat;
		my ($x,$y) = _latlon_to_xy(
			$self->{MAP},$locations{$pusson}->{LAT},$locations{$pusson}->{LON}
		);
		if (defined $x and defined $y){
			$self->_add_to_map(
				$x,$y, $pusson,$locations{$pusson}->{PLACE}
			);
		}
	}
}


#
# Private method: _add_to_map (x,yx,name,place)
#
# Adds to the current image and to the HTML being created
# 	cf. $self->{IM}, $self->{HTML}.
#
# 	Accepts: x and y co-ordinates in the current map ($self->{MAP})
#			 name of entry
#			 optionally, name of place
#
sub _add_to_map { my ($self, $x,$y,$name,$place) = (@_);
	# Add to the image
	die "Please call this METHOD with x,y, name,place!" if not defined $self or not defined $x or not defined $y or not defined $name; # Place is optional

	if ($x<0 or $x>$MAPS{$self->{MAP}}->{DIM}[0]
	or  $y<0 or $y>$MAPS{$self->{MAP}}->{DIM}[1]){
			warn "\t...out of the map bounds, not adding.\n" if $chat;
			return undef;
	}

	$name  =~ s/'/\\'/g;
	$place =~ s/'/\\'/g;

	for (0..$MAPS{$self->{MAP}}->{SPOTSIZE}){
		$self->{IM}->arc($x,$y,$MAPS{$self->{MAP}}->{SPOTSIZE}-$_,$MAPS{$self->{MAP}}->{SPOTSIZE}-$_,0,360,$self->{SPOTCOLOUR});
	}

	# Add to the HTML
	$self->{HTML} .= "<area "
		. "shape='circle' coords='$x,$y,$MAPS{$self->{MAP}}->{SPOTSIZE}' "
		. "alt='$name ($place)' title='$name";
	$self->{HTML} .= " ($place)" if defined $place;
	$self->{HTML} .= "' href='#' target='_self'>\n";
	warn "\t...adding to map at $x,$y\n" if $chat;
}



#
# Private methods: _add_html_top, _add_map_top, _add_map_bottom, _add_html_bottom
#
# Call before adding elements to the map, to initiate up the HTML image map, and include the HTML iamge.
# Optional second argument used as HTML TITLE element contents when no $self->{MAP} has been defined.
#
sub _add_html_top { my $self=shift;
	$self->{HTML} =
	"<html><head><title>";
	if (exists $self->{MAP}){
		$self->{HTML}.="$self->{TITLE} $self->{MAP} map";
	} else {
		$self->{HTML} .= $_[0] if defined $_[0];
	}
	$self->{HTML} .= "</title><meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'></head>\n<body>\n"
}

sub _add_map_top { my ($self ) = (shift);
	my ($x,$y) = $self->{IM}->getBounds();
	$self->{HTML}
		.="<div align='center'>\n"
		. "<img src='$self->{IMGPATH}' width='$x' height='$y' usemap='#$self->{MAP}' border='1'>\n"
		. "<map name='$self->{MAP}'>\n\n";
}

sub _add_map_bottom { my ($self) = (shift);
	$self->{HTML} .= "\n</map>\n</div>\n";
}

sub _add_html_bottom { my ($self) = (shift);
	$self->{HTML} .= "\n</body></html>\n\n";
}








#
# Sub: &_latlon_to_xy (map,latitude,longitude)
#
# Map latitude and longitude to pixel on $MAPS{$map}
#
#	Accepts: name of map to map onto (key to our %MAPS)
#			 latitude, longitude
#	Returns: the new co-ords on the map passed
#
#	As it took me some time to get around this,
#	I've not optimized the code for fear. But hey,
#	at least you get to see my workings, as they
#	said in 'O' level Maths....
#
sub _latlon_to_xy { my ($map,$lat,$lon) = (@_);
	if ($lat>90) {warn "\t...can't add, incomplete/missing location details ($lat,$lon).\n" if $chat; return undef;}
	# Lat, Lon in miles
	my $m_lat = $lat - @{$MAPS{$map}->{ANCHOR_LATLON}}[0];
	my $m_lon = $lon - @{$MAPS{$map}->{ANCHOR_LATLON}}[1];
	$m_lat = $m_lat * $LAT[int $lat];
	$m_lon = $m_lon * 69;
#	my $loni = int $lon;
#	$loni = -$loni if $loni<0;
#	if ($loni>90){ $loni = 90 - ($loni-90); }
#	$m_lon = $m_lon * ($LON[$loni]);

	# Invert to plot on map
	$m_lat = -$m_lat;
	my $px_lat = $m_lat * $MAPS{$map}->{ONEMILE};
	my $px_lon = $m_lon * $MAPS{$map}->{ONEMILE};
	# As zero degrees latitude is the equator, lat (y) is plotted
	# from the bottom of the image - this must be inverted!
	$px_lat += @{$MAPS{$map}->{ANCHOR_PIXELS}}[1];
	$px_lon += @{$MAPS{$map}->{ANCHOR_PIXELS}}[0];
	# Return in x,y order
	return (int $px_lon, int $px_lat);
}



=head2 &load_db

A subroutine that loads a database hash from the specified path.

Returns nothing, but does C<die> on failure.

=cut

sub load_db { my $dbname = shift;
	local *IN;
	open IN,"$dbname" or die "Couldn't open the configuration file <$dbname> for reading";
	read IN, $_, -s IN;
	close IN;
	my $VAR1; # will come from evaluating the file produced by Data::Dumper.
	eval ($_);
	warn $@ if $@;
	%locations = %{$VAR1};

}


=head2 &save_db

A subroutine, not a method, that saves the currently loaded database hash to the filename specified as the only arguemnt.

Note tha tyou may want to load a db before saving.

Returns nothing, but does C<die> on failure.

=cut

# Simply uses C<Data::Dumper> to dump the hash that stores the user values

sub save_db { my $dbname = shift;
	local *OUT;
	open OUT,">$dbname" or die "Couldn't open the configuration file <$dbname> for writing";
	print OUT Dumper(\%locations);
	close OUT;
}


=head2 &add_entry

A subroutine, not a method, that accepts: $name, $country, $postcode

Looks up on MapBlast.com the supplied details, and adds them to the db.

If an entry already exists for $name, will return C<undef> unless
the global scalar C<$ADDENTRY> is set to it's default value of C<MULTIPLE>,
in which case $name will be appended with $country and $postcode.

Does not save them to file - you must do that manually (L<"save_db">), but
note that you may wish to load the db before adding to it and saving.

Incidentaly returns a reference to the new key.

=cut

sub add_entry { my ($name,$country,$postcode) = (shift,shift,shift);
	die "Can't add_entry without \$name, \$country, \$postcode "
		unless (defined $name and defined $country and defined $postcode);

	my ($lat,$lon,$address) = WWW::MapBlast::latlon($country,$postcode);
	$lat = 11111111 if not defined $lat or $lat eq '';
	$lon = 11111111 if not defined $lon or $lon eq '';
	if (not defined $address or $address eq ''){
		$address = "$postcode $country - MapBlast.com didn't know"
	}

	if (exists %locations -> {$name} ){
		if ($ADDENTRY ne 'MULTIPLE'){
			warn "Not adding duplicate entry for $name at $postcode, $country.\n" if $chat;
			return undef;
		}
		$name .= " ($postcode $country)";
	}

	%locations -> {$name} = {
			PLACE=>$address,
			LAT=>$lat,
			LON=>$lon,
	};

	return \$locations{$name};
}



=head2 &remove_entry

A subroutine, not a method, that accepts the name field of the entry in the db, and returns
C<1> on success, C<undef> if no such entry exists.

=cut

sub remove_entry { my ($name) = (shift);
	return undef if not exists %locations -> {$name};
	delete %locations -> {$name};
	return 1;
}


#
# _create_thumbnail (path to image, size of longest side)
# Creates and saves a thumbnail of the specified image.
# Returns the name of the image
#
sub _create_thumbnail { my ($path,$size) = (shift,shift);
	# Load your source image
	die "Passed no filepath to create_thumbnail " if not defined $path;
	$path .= '.jpg';
	die "Passed bad filepath to create_thumbnail <$path>" if not defined $path or not -e $path;
	$size = 75 if not defined $size;
	open IN, $path  or die "Could not open <$path> although it exists.";
	my $srcImage = GD::Image->newFromJpeg(*IN);
	close IN;

	# Create the thumbnail from it, where the biggest side is 50 px
	my ($thumb,$x,$y) = Image::GD::Thumbnail::create($srcImage,$size);
	$path =~ s/\.jpg$/_t.jpg/;
	# Save your thumbnail
	open OUT, ">$path" or die "Could not save as <$path> ";
	binmode OUT;
	print OUT $thumb->jpeg;
	close OUT;
	return $x,$y;
}

=head1 NOTES ON LATITUDE AND LONGITUDE

After L<http://www.mapblast.com/myblast/helpFaq.mb#2|http://www.mapblast.com/myblast/helpFaq.mb#2>:

=over 4

Zero degrees latitude is the equator, with the North pole at 90 degrees latitude and the South pole at -90 degrees latitude.
one degree is approximately 69 miles. Greenwich, England is at 51.466 degrees north of the equator.

Zero degrees longitude goes through Greenwich, England.
Again, Each 69 miles from this meridian represents approximately 1 degree of longitude.
East/West is plus/minus respectively.

=back

Actually, latitude and longitude vary depending upon the degree in hand:
see L<The Compton Encyclopdedia|http://www.comptons.com/encyclopedia/ARTICLES/0100/01054720_A.html#P17> for more information.

=cut

#
# Make @LAT and @LON to get length of a degree
#
sub _make_latlon {
	LAT:{
		my $i = 0;
		foreach (@_LAT){
			for my $j (0..4){
				last LAT if $i+$j>90;
				$LAT[$i+$j] = $_;
			}
			$i += 5;
		}
	}

	LON:{
		my $i = 0;
		foreach (@_LON){
			for my $j (0..4){
				last LON if $i+$j>90;
				$LON[$i+$j] = $_;
			}
			$i += 5;
		}
	}
}

=head1 ADDING MAPS

The next version, if there is one, may allow you to pass map data to the constructor.
In the meantime, adding maps is not in itself a big deal, perl-wise. Add a new key to
the C<%MAPS> hash, with the value of an anonymous hash with the following content:

=over 4

=item FILE

scalar file name of map

=item DIM

anon array of dimensions of map in pixels [x,y].
You could create DIM on the fly using C<GD>, but there's probably no point, as you're
almost certainly going to have to edit the map to align it with longitude and latitude
(if you find a stock of public-domain maps that are already aligned, please drop
the author a line).

=item SPOTSIZE

scalar number for the size of the map-marker spots, in pixels

=item ANCHOR_PIXELS

anon array of the pixel location of the arbitrary anchor pont [x,y]

=item ANCHOR_LATLON

anon array of the latitude/longitude of the arbitrary anchor pont [x,y]

=item ANCHOR_NAME

scalar name of the anchor, when marked on map

=item ANCHOR_PLACE

scalar place name of the anchor, when marked on map

=item ONEMILE

scalar representation of 1 mile in pixels

=back

=head1 REVSIONS

0.25 Clean IMG path and double-header bugs
0.22 Added thumbnail images to index page
0.23 Added more documentation; escaping of href text

=head1 SEE ALSO

perl(1); L<GD>; L<File::Basename>; L<Acme::Pony>; L<Data::Dumper>; L<WWW::MapBlast>; L<Image::GD::Thumbnail>

=head1 THANKS

Thanks to the London.pm group for their test data and insipration, to Leon for his patience with all that mess on the list, to Philip Newton for his frankly amazing knowledge of international postcodes.

Thanks also to L<About.com|http://wwww.about.com>, L<The University of Texas|http://www.lib.utexas.edu/maps>,
and L<The Ordnance Survey|http://www.ordsvy.gov.uk/freegb/index.htm#maps> for their public-domain maps.

=head1 AUTHOR

Lee Goddard <lgoddard@cpan.org>

=head1 COPYRIGHT

Copyright (C) Lee Goddard, 2001.  All Rights Reserved.

This module is supplied and may be used under the same terms as Perl itself.

The public domain maps provided with this distribution are the property of their respective copyright holders.

=cut

#	use Image::Maps::Plot::FromPostcode;

#	Image::Maps::Plot::FromPostcode::all("E:/src/pl/");

1;

__END__

