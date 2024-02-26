#!/usr/bin/perl
use utf8;
use Encode;
no warnings;

$mapFile = $ARGV[0];
$inputWordFile = $ARGV[1];
$outputFile = $ARGV[2];

%charHash = ();
open(INPW,"<$inputWordFile");
$inputWord = <INPW>;
chomp($inputWord);
$inputWord =~ s/^\s+|\s+$//g;

open(INP,"<$mapFile");
open(OUT,">$outputFile");

$input = utf2UniCode($inputWord);

LINE: while( $line = <INP> )
{
	chomp($line);
	if($line =~ index($line,'#'))
	{
		redo LINE;
	}
	$line =~ s/^\s+|\s+$//g;
	
	@wordArray = split(/\s+/,$line);
#	print $wordArray[0]."    =>    ".$wordArray[1]."\n";
	$charHash{decode_utf8($wordArray[0])} = $wordArray[1];
#	print $charHash{$wordArray[0]}."    =>    ".$wordArray[0]."\n";
}

$input =~ s/^\s+|\s+$//g;
chomp($input);
#print "input $input\n";
#$input = decode_utf8($input);
@inputArray = split(/\s+/,$input);

foreach $t (@inputArray)
{
	if(exists $charHash{$t})
	{
		print OUT $charHash{$t};
	}
	else
	{
		print $t;
	}
}


sub utf2UniCode {

	my $t;
	my $word  = $_[0];
	chomp($word);
	
	my $retArray;
	
	my @utf8char;
	my $initial = 0;
	my @test;
	my $tempword;
	my $hexword;
	my $decword;
	
 	foreach ( split( //, $word ) ) {
		push( @utf8char, &string2bin($_) );
	}
	
	my $nutf8char = $#utf8char + 1;
	for ( my $loop = 0 ; $loop < $nutf8char ; ) {
		$t = 0;
		my $dec_input = &hex2dec( $utf8char[$loop] );
		if ( ( my $value = $dec_input & 128 ) == 0 ) {
			$t = $t | $dec_input;
			$loop++;
		}

		elsif ( ( $value = $dec_input & 240 ) == 224 ) {

			$t     = $t | ( $dec_input & 15 );
			$t     = $t << 6;
			$loop++;

			$dec_input = &hex2dec( $utf8char[$loop] );
			$t         = $t | ( $dec_input & 63 );
			$t         = $t << 6;
			$loop++;

			$dec_input = &hex2dec( $utf8char[$loop] );
			$t = $t | ( $dec_input & 63 );
			$loop++;
		}

		else {
			$loop++;
		}
		@tempArr=$t;

		my $hex = &dec2hex($t);

		$decword .= " " . $t;
		$hexword .= " " . $hex;
	}
	$hexword =~ s/^\s+|\s+$//g;
	$decword =~ s/^\s+|\s+$//g;
	my @hextemp     = split( /\s+/,            $hexword );
	my @dectemp     = split( /\s+/,            $decword );
	
	for(my $i = 0; $i < $#dectemp+1;$i++)
	{
		if($dectemp[$i] >= &hex2dec("B95") && $dectemp[$i] <= &hex2dec("BB9"))
		{
			if($dectemp[$i+1] >= &hex2dec("BBE") && $dectemp[$i+1] <= &hex2dec("BCD"))
			{
				$retArray .= chr(hex $hextemp[$i]).chr(hex $hextemp[$i+1])." ";
				$i++;
			}
			else
			{
#				print $charHash{chr(hex &dec2hex($dectemp[$i]))};
				$retArray .= chr(hex $hextemp[$i])." ";
#				print chr(hex $hextemp[$i]);
			}
		}
		else
		{
#			print $charHash{chr(hex &dec2hex($dectemp[$i]))};
			$retArray .= chr(hex $hextemp[$i])." ";
			#print chr(hex $hextemp[$i]);
		}
	}
	
	return $retArray;
}

sub string2bin($) {
	return sprintf( "%02x ", ord($_) );
}

sub hex2dec($) {
	eval "return sprintf(\"\%d\", 0x$_[0])";
}

sub dec2hex {
	my $decnum = $_[0];
	my ( $hexnum, $tempval );
	while ( $decnum != 0 ) {
		$tempval = $decnum % 16;
		$tempval = chr( $tempval + 55 ) if ( $tempval > 9 );
		$hexnum  = $tempval . $hexnum;
		$decnum  = int( $decnum / 16 );
		if ( $decnum < 16 ) {
			$decnum = chr( $decnum + 55 ) if ( $decnum > 9 );
			$hexnum = $decnum . $hexnum;
			$decnum = 0;
		}
	}
	return $hexnum;
}
