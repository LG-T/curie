use Renard::Curie::Setup;
package Renard::Curie::Language::EN;

use Renard::Curie::Types qw(InstanceOf);
use Function::Parameters;

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

1;
