#!/usr/bin/env perl

use Test::Most;

use lib 't/lib';
use CurieTestHelper;

use Renard::Curie::Setup;
use Renard::Curie::Model::Document::PDF;
use Renard::Curie::Language::EN;
use Function::Parameters;

my $pdf_ref_path = try {
	CurieTestHelper->test_data_directory->child(qw(PDF Adobe pdf_reference_1-7.pdf));
} catch {
	plan skip_all => "$_";
};

plan tests => 1;

subtest "Split sentences" => fun {
	my $pdf_doc = Renard::Curie::Model::Document::PDF->new(
		filename => $pdf_ref_path
	);

	my $tagged = $pdf_doc->get_textual_page( 23 );

	Renard::Curie::Language::EN::apply_sentence_offsets_to_blocks( $tagged );
	my @sentences = ();

	$tagged->iter_substr_nooverlap(
		sub {
			my ( $substring, %tags ) = @_;
			if( defined $tags{sentence} ) {
				note "$substring\n=-=";
				push @sentences, $substring;
			}
		},
		only => [ 'sentence' ],
	);

	# even though there is a dot in this sentence, it does not get split
	my $sentence_with_dot = 'It includes the precise documentation of the underlying imaging model from Post-Script along with the PDF-specific features that are combined in version 1.7 of the PDF standard.';
	cmp_deeply
		\@sentences,
		superbagof(
			'Preface',  # heading
			'23',       # page number
			$sentence_with_dot,
		),
		'A block is considered its own sentence';
};
