use Renard::Curie::Setup;
package Renard::Curie::Component::PageDrawingArea;
# ABSTRACT: Component that implements document page navigation

use Moo;
use Glib 'TRUE', 'FALSE';
use Glib::Object::Subclass 'Gtk3::Bin';
use Renard::Curie::Types qw(RenderableDocumentModel RenderablePageModel
	PageNumber Bool InstanceOf PositiveOrZeroInt);
use Function::Parameters;

use Renard::Curie::Language::EN;
use List::AllUtils qw(uniq);
use Scalar::Util qw(refaddr);

=attr document

The L<RenderableDocumentModel|Renard:Curie::Types/RenderableDocumentModel> that
this component displays.

=cut
has document => (
	is => 'rw',
	isa => (RenderableDocumentModel),
	required => 1
);

=attr current_rendered_page

A L<RenderablePageModel|Renard:Curie::Types/RenderablePageModel> for the
current page.

=cut
has current_rendered_page => (
	is => 'rw',
	isa => (RenderablePageModel),
);

=attr current_page_number

A L<PageNumber|Renard:Curie::Types/PageNumber> for the current page being
drawn.

=cut
has current_page_number => (
	is => 'rw',
	isa => PageNumber,
	default => 1,
	trigger => 1 # _trigger_current_page_number
	);

=attr current_sentence_number

TODO

=cut
has current_sentence_number => (
	is => 'rw',
	isa => PositiveOrZeroInt,
	trigger => 1, # _trigger_current_sentence_number
	default => 0,
	);

=attr current_text_page

TODO

=cut
has current_text_page => (
	is => 'lazy', # _build_current_text_page
	clearer => 1, # clear_current_text_page
);

=attr drawing_area

The L<Gtk3::DrawingArea> that is used to draw the document on.

=cut
has drawing_area => (
	is => 'rw',
	isa => InstanceOf['Gtk3::DrawingArea'],
);

=attr scrolled_window

The L<Gtk3::ScrolledWindow> container for the L</drawing_area>.

=cut
has scrolled_window => (
	is => 'rw',
	isa => InstanceOf['Gtk3::ScrolledWindow'],
);

=classmethod FOREIGNBUILDARGS

  classmethod FOREIGNBUILDARGS(@)

Initialises the L<Gtk3::Bin> super-class.

=cut
classmethod FOREIGNBUILDARGS(@) {
	return ();
}

=method BUILD

  method BUILD

Initialises the component's contained widgets and signals.

=cut
method BUILD {
	# so that the widget can take input
	$self->set_can_focus( TRUE );

	$self->setup_button_events;
	$self->setup_text_entry_events;
	$self->setup_drawing_area;
	$self->setup_number_of_pages_label;
	$self->setup_keybindings;

	# add as child for this L<Gtk3::Bin>
	$self->add(
		$self->builder->get_object('page-drawing-component')
	);
}

=method setup_button_events

  method setup_button_events()

Sets up the signals for the navigational buttons.

=cut
method setup_button_events() {
	$self->builder->get_object('button-first')->signal_connect(
		clicked => \&on_clicked_button_first_cb, $self );
	$self->builder->get_object('button-last')->signal_connect(
		clicked => \&on_clicked_button_last_cb, $self );

	$self->builder->get_object('button-forward')->signal_connect(
		clicked => \&on_clicked_button_forward_cb, $self );
	$self->builder->get_object('button-back')->signal_connect(
		clicked => \&on_clicked_button_back_cb, $self );

	$self->set_navigation_buttons_sensitivity;
}

=callback on_clicked_button_first_cb

  fun on_clicked_button_first_cb($button, $self)

Callback for when the "First" button is pressed.
See L</set_current_page_to_first>.

=cut
fun on_clicked_button_first_cb($button, $self) {
	$self->set_current_page_to_first;
}

=callback on_clicked_button_last_cb

  fun on_clicked_button_last_cb($button, $self)

Callback for when the "Last" button is pressed.
See L</set_current_page_to_last>.

=cut
fun on_clicked_button_last_cb($button, $self) {
	$self->set_current_page_to_last;
}

=callback on_clicked_button_forward_cb

  fun on_clicked_button_forward_cb($button, $self)

Callback for when the "Forward" button is pressed.
See L</set_current_page_forward>.

=cut
fun on_clicked_button_forward_cb($button, $self) {
	$self->set_current_page_forward;
}

=callback on_clicked_button_back_cb

  fun on_clicked_button_back_cb($button, $self)

Callback for when the "Back" button is pressed.
See L</set_current_page_back>.

=cut
fun on_clicked_button_back_cb($button, $self) {
	$self->set_current_page_back;
}

=method setup_text_entry_events

  method setup_text_entry_events()

Sets up the signals for the text entry box so the user can enter in page
numbers.

=cut
method setup_text_entry_events() {
	$self->builder->get_object('page-number-entry')->signal_connect(
		activate => \&on_activate_page_number_entry_cb, $self );
}

=method setup_drawing_area

  method setup_drawing_area()

Sets up the L</drawing_area> so that it draws the current page.

=cut
method setup_drawing_area() {
	my $drawing_area = Gtk3::DrawingArea->new();
	$self->drawing_area( $drawing_area );
	$drawing_area->signal_connect( draw => fun (
			(InstanceOf['Gtk3::DrawingArea']) $widget,
			(InstanceOf['Cairo::Context']) $cr) {
		my $rp = $self->document->get_rendered_page(
			page_number => $self->current_page_number,
		);
		$self->current_rendered_page( $rp );
		$self->on_draw_page_cb( $cr );

		return TRUE;
	}, $self);

	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_hexpand(TRUE);
	$scrolled_window->set_vexpand(TRUE);

	$scrolled_window->add($drawing_area);
	$scrolled_window->set_policy( 'automatic', 'automatic');
	$self->scrolled_window($scrolled_window);

	my $vbox = $self->builder->get_object('page-drawing-component');
	$vbox->pack_start( $scrolled_window, TRUE, TRUE, 0);
}

=method setup_number_of_pages_label

  method setup_number_of_pages_label()

Sets up the label that shows the number of pages in the document.

=cut
method setup_number_of_pages_label() {
	$self->builder->get_object("number-of-pages-label")
		->set_text( $self->document->last_page_number );
}

=method setup_keybindings

  method setup_keybindings()

Sets up the signals to capture key presses on this component.

=cut
method setup_keybindings() {
	$self->signal_connect( key_press_event => \&on_key_press_event_cb, $self );
}

=callback on_key_press_event_cb

  fun on_key_press_event_cb($window, $event, $self)

Callback that responds to specific key events and dispatches to the appropriate
handlers.

=cut
fun on_key_press_event_cb($window, $event, $self) {
	if($event->keyval == Gtk3::Gdk::KEY_Page_Down){
		$self->set_current_page_forward;
	} elsif($event->keyval == Gtk3::Gdk::KEY_Page_Up){
		$self->set_current_page_back;
	} elsif($event->keyval == Gtk3::Gdk::KEY_Up){
		decrement_scroll($self->scrolled_window->get_vadjustment);
	} elsif($event->keyval == Gtk3::Gdk::KEY_Down){
		increment_scroll($self->scrolled_window->get_vadjustment);
	} elsif($event->keyval == Gtk3::Gdk::KEY_Right){
		increment_scroll($self->scrolled_window->get_hadjustment);
	} elsif($event->keyval == Gtk3::Gdk::KEY_Left){
		decrement_scroll($self->scrolled_window->get_hadjustment);
	}
}

=func increment_scroll

  fun increment_scroll( (InstanceOf['Gtk3::Adjustment']) $current )

Helper function that scrolls down by the scrollbar's step increment.

=cut
fun increment_scroll( (InstanceOf['Gtk3::Adjustment']) $current ) {
	my $adjustment = $current->get_value + $current->get_step_increment;
	$current->set_value($adjustment);
}

=func decrement_scroll

  fun decrement_scroll( (InstanceOf['Gtk3::Adjustment']) $current )

Helper function that scrolls up by the scrollbar's step increment.

=cut
fun decrement_scroll( (InstanceOf['Gtk3::Adjustment']) $current ) {
	my $adjustment = $current->get_value - $current->get_step_increment;
	$current->set_value($adjustment);
}

=method refresh_drawing_area

  method refresh_drawing_area()

This forces the drawing area to redraw.

=cut
method refresh_drawing_area() {
	return unless $self->drawing_area;

	$self->drawing_area->queue_draw;
}

=callback on_draw_page_cb

  method on_draw_page_cb( (InstanceOf['Cairo::Context']) $cr )

Callback that draws the current page on to the L</drawing_area>.

=cut
method on_draw_page_cb( (InstanceOf['Cairo::Context']) $cr ) {
	# NOTE: we may want to change the signature to match the other
	# callbacks with $self as the last argument.
	$self->set_navigation_buttons_sensitivity;

	my $img = $self->current_rendered_page->cairo_image_surface;

	my @top_left = ( ($self->drawing_area->get_allocated_width -
		$self->current_rendered_page->width) / 2, 0 );
	$cr->set_source_surface($img, @top_left);

	$cr->paint;

	$self->drawing_area->set_size_request(
		$self->current_rendered_page->width,
		$self->current_rendered_page->height );

	$self->builder->get_object('page-number-entry')
		->set_text($self->current_page_number);

	if( @{ $self->current_text_page } ) {
		my $sentence = $self->current_text_page->[
			$self->current_sentence_number
		];
		for my $bbox_str ( @{ $sentence->{bbox} } ) {
			my $bbox = [ split ' ', $bbox_str ];
			$cr->rectangle(
				$top_left[0] + $bbox->[0],
				$top_left[1] + $bbox->[1],
				$bbox->[2] - $bbox->[0],
				$bbox->[3] - $bbox->[1],
			);
		}
		$cr->set_source_rgba(1, 0, 0, 0.2);
		$cr->fill_preserve;
	}
}

=begin comment

=method _trigger_current_page_number

  method _trigger_current_page_number

Called whenever the L</current_page_number> is changed. This allows for telling
the component to retrieve the new page and redraw.

=end comment

=cut
method _trigger_current_page_number {
	$self->clear_current_text_page;
	$self->current_sentence_number(0);
	$self->refresh_drawing_area;
}

method _trigger_current_sentence_number {
	$self->refresh_drawing_area;
	$self->app->tts_window->update;
}

=callback on_activate_page_number_entry_cb

  fun on_activate_page_number_entry_cb( $entry, $self )

Callback that is called when text has been entered into the page number entry.

=cut
fun on_activate_page_number_entry_cb( $entry, $self ) {
	my $text = $entry->get_text;
	if ($text =~ /^[0-9]+$/ and $text <= $self->document->last_page_number
			and $text >= $self->document->first_page_number) {
		$self->current_page_number( $text );
	}
}

=method set_current_page_forward

  method set_current_page_forward()

Increments the current page number if possible.

=cut
method set_current_page_forward() {
	if( $self->can_move_to_next_page ) {
		$self->current_page_number( $self->current_page_number + 1 );
	}
}

=method set_current_page_back

  method set_current_page_back()

Decrements the current page number if possible.

=cut
method set_current_page_back() {
	if( $self->can_move_to_previous_page ) {
		$self->current_page_number( $self->current_page_number - 1 );
	}
}

=method set_current_page_to_first

  method set_current_page_to_first()

Sets the page number to the first page of the document.

=cut
method set_current_page_to_first() {
	$self->current_page_number( $self->document->first_page_number );
}

=method set_current_page_to_last

  method set_current_page_to_last()

Sets the current page to the last page of the document.

=cut
method set_current_page_to_last() {
	$self->current_page_number( $self->document->last_page_number );
}

=method can_move_to_previous_page

  method can_move_to_previous_page() :ReturnType(Bool)

Predicate to check if we can decrement the current page number.

=cut
method can_move_to_previous_page() :ReturnType(Bool) {
	$self->current_page_number > $self->document->first_page_number;
}

=method can_move_to_next_page

  method can_move_to_next_page() :ReturnType(Bool)

Predicate to check if we can increment the current page number.

=cut
method can_move_to_next_page() :ReturnType(Bool) {
	$self->current_page_number < $self->document->last_page_number;
}

=method set_navigation_buttons_sensitivity

  set_navigation_buttons_sensitivity()

Enables and disables forward and back navigation buttons when at the end and
start of the document respectively.

=cut
method set_navigation_buttons_sensitivity() {
	my $can_move_forward = $self->can_move_to_next_page;
	my $can_move_back = $self->can_move_to_previous_page;

	for my $button_name ( qw(button-last button-forward) ) {
		$self->builder->get_object($button_name)
			->set_sensitive($can_move_forward);
	}

	for my $button_name ( qw(button-first button-back) ) {
		$self->builder->get_object($button_name)
			->set_sensitive($can_move_back);
	}
}

method _build_current_text_page {
	return [] unless $self->document->can('get_textual_page');
	my $txt = $self->document->get_textual_page($self->current_page_number);
	Renard::Curie::Language::EN::apply_sentence_offsets_to_blocks($txt);

	my @sentence_spans = ();
	$txt->iter_extents(sub {
		my ($extent, $tag_name, $tag_value) = @_;
		my $data = {
			sentence => $extent->substr,
			extent => $extent,
		};
		my $start = $extent->start;
		my $end = $extent->end;
		my $last_span = {};
		for my $pos ($start..$end-1) {
			my $value = $txt->get_tag_at($pos,'span');
			if( defined $value && refaddr $last_span != refaddr $value ) {
				$last_span = $value;
				push @{ $data->{spans} }, $value;
			}
		}
		push @sentence_spans, $data;
	}, only => ['sentence'] );

	for my $sentence (@sentence_spans) {
		my $extent = $sentence->{extent};
		$sentence->{first_char} = $txt->get_tag_at( $extent->start, 'char' );
		$sentence->{last_char} = $txt->get_tag_at( $extent->end-1, 'char' );
		my @spans = @{ $sentence->{spans} };
		my @bb = ();
		for my $span (@spans) {
			push @bb, $span->{bbox};
		}
		if( $sentence->{first_char} != $spans[0]{char}[0] ) {
			my $span = shift @bb;
			my @span_bbox = split ' ', $span;
			my @char_bbox = split ' ', $sentence->{first_char}{bbox};
			$span_bbox[0] = $char_bbox[0];
			unshift @bb, join(' ', @span_bbox);
		}
		if( $sentence->{last_char} != $spans[-1]{char}[-1] ) {
			my $span = pop @bb;
			my @span_bbox = split ' ', $span;
			my @char_bbox = split ' ', $sentence->{last_char}{bbox};
			$span_bbox[2] = $char_bbox[2];
			push @bb, join(' ', @span_bbox);
		}
		$sentence->{bbox} = \@bb;
	}

	\@sentence_spans;
}

with qw(
	Renard::Curie::Component::Role::FromBuilder
	Renard::Curie::Component::Role::UIFileFromPackageName
	Renard::Curie::Component::Role::HasParentApp
);

1;
