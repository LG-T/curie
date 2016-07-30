use Renard::Curie::Setup;
package Renard::Curie::Model::Document::PDF;
# ABSTRACT: document that represents a PDF file

use Moo;
use Renard::Curie::Data::PDF;
use Renard::Curie::Model::Page::RenderedFromPNG;
use Renard::Curie::Model::Outline;
use Renard::Curie::Types qw(PageNumber InstanceOf);
use Function::Parameters;
use String::Tagged;

extends qw(Renard::Curie::Model::Document);

=begin comment

=method _build_last_page_number

Retrieves the last page number of the PDF. Currently implemented through
C<mutool>.

=end comment

=cut
method _build_last_page_number :ReturnType(PageNumber) {
	my $info = Renard::Curie::Data::PDF::get_mutool_page_info_xml(
		$self->filename
	);

	return scalar @{ $info->{page} };
}

=method get_rendered_page

  method get_rendered_page( (PageNumber) :$page_number )

See L<Renard::Curie::Model::Document::Role::Renderable>.

=cut
# TODO : need to implement zoom_level option
method get_rendered_page( (PageNumber) :$page_number ) {
	my $png_data = Renard::Curie::Data::PDF::get_mutool_pdf_page_as_png(
		$self->filename, $page_number,
	);

	return Renard::Curie::Model::Page::RenderedFromPNG->new(
		page_number => $page_number,
		png_data => $png_data,
		zoom_level => 1,
	);
}

method _build_outline {
	my $outline_data = Renard::Curie::Data::PDF::get_mutool_outline_simple(
		$self->filename
	);

	return Renard::Curie::Model::Outline->new( items => $outline_data );
}

=method get_textual_page

  method get_textual_page( (PageNumber) $page_number ) :ReturnType(InstanceOf['String::Tagged'])

Returns a L<String::Tagged> representation of the PDF textual data for a given
page. The return value contains tags that indicate the extent of each level as
defined by L<Renard::Curie::Data::PDF::get_mutool_text_stext_xml>:

=for :list
* C<page>,
* C<block>,
* C<line>,
* C<span>, and
* C<char>


The values associated with these tags can be used to find the bounding box for
the symbols on the page.

=cut
method get_textual_page( (PageNumber) $page_number )
		:ReturnType(InstanceOf['String::Tagged']) {
	my $page_st = String::Tagged->new;

	my $stext = Renard::Curie::Data::PDF::get_mutool_text_stext_xml(
		$self->filename,
		$page_number
	);

	my $levels = [ qw(doc page block line span char) ];
	_walk_page_data( $page_st, $stext, 0, $levels );

	$page_st;
}

fun _walk_page_data( $tagged, $data, $depth, $levels ) {
	my $level_tagged = String::Tagged->new("");

	if( $depth == @$levels - 1 ) {
		# last level is the character, so we append that to the string
		$level_tagged .= $data->{c};
	} else {
		# empty pages will not have this data
		return unless exists $data->{ $levels->[$depth+1] };

		my @data_next = @{ $data->{ $levels->[$depth+1] } };
		for my $next_data (@data_next) {
			_walk_page_data( $level_tagged, $next_data, $depth+1, $levels );
		}
	}
	$level_tagged->apply_tag(0, $level_tagged->length, $levels->[$depth] => $data );

	$tagged->append_tagged($level_tagged);

	return;
}

with qw(
	Renard::Curie::Model::Document::Role::FromFile
	Renard::Curie::Model::Document::Role::Pageable
	Renard::Curie::Model::Document::Role::Renderable
	Renard::Curie::Model::Document::Role::Cacheable
	Renard::Curie::Model::Document::Role::Outlineable
);

1;
