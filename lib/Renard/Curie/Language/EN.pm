use Renard::Curie::Setup;
package Renard::Curie::Language::EN;

use Renard::Curie::Types qw(InstanceOf);
use Function::Parameters;
use Text::Unidecode;

=func apply_sentence_offsets_to_blocks

  fun apply_sentence_offsets_to_blocks( (InstanceOf['String::Tagged']) $text )

Retrieves the sentence offsets for each part of the C<$text> string that has
been tagged as a C<block> and apply a C<sentence> tag to each sentence.

This uses L<Lingua::EN::Sentence::Offsets> internally to determine the location
of each sentence.

=cut
fun apply_sentence_offsets_to_blocks( (InstanceOf['String::Tagged']) $text ) {
	# loading here so that utf8::all does not effect everything
	require Lingua::EN::Sentence::Offsets;
	Lingua::EN::Sentence::Offsets->import(qw/get_offsets add_acronyms/);
	$text->iter_extents_nooverlap(
		sub {
			my ( $extent, %tags ) = @_;
			my $offsets = get_offsets( $extent->substr );
			# NOTE Offsets need to be sorted because it appears that they might not
			# be in order.  Not sure what that means or if that is a bug.
			$offsets = [ sort { $a->[0] <=> $b->[0] } @$offsets ];
			my $id = 0;
			for my $o (@$offsets) {
				$text->apply_tag(
					$extent->start + $o->[0],
					$o->[1]-$o->[0],
					sentence => $id++ );
			}
		},
		only => [ 'block' ],
	);
}

fun preprocess_for_tts( $text ) {
	$_ = $text;
	$_ = unidecode($_); # FIXME this is a sledgehammer approach

	s/\[(\d+(,\s*\d+)*)\]/citation $1/gi; # [12,28] -> citations 12, 28
	s/\bFig[. ]*(\d+)/Figure $1/gi; # Fig. 4 -> Figure 4
	s/\bSec[. ]*(\d+)/Section $1/gi; # Sec. 2 -> Section 2
	s/\bEq[. ]*(\d+)/Equation $1/gi; # Eq. 3 -> Equation 3
	s/\be\.?g\.?,/for example,/gi; # (e.g., text) -> (for example, text)
	s/\bi\.?e\.?,/that is,/gi; # (i.e., text) -> (that is, text)
	s/\bet\s*al\.?/and others/gi; # et al -> and others
	$_;
}

1;
