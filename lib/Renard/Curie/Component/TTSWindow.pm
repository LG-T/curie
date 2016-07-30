use Renard::Curie::Setup;
package Renard::Curie::Component::TTSWindow;
# ABSTRACT: Component used to control speech synthesis

use Moo;
use Function::Parameters;
use Speech::Synthesis;
use List::AllUtils qw(first);

has playing => (
	is => 'rw',
	default => sub { 0 },
);

has synth => (
	is => 'lazy', # _build_synth
);

method BUILD {
	$self->builder->get_object('tts-window')
		->signal_connect(
			'delete-event'
			# TODO do nothing for now
			=> sub { undef; } );
	$self->builder->get_object('button-play')
		->signal_connect(
			clicked =>
			\&on_clicked_button_play_cb, $self );
	$self->builder->get_object('button-next')
		->signal_connect(
			clicked =>
			\&on_clicked_button_next_cb, $self );
	$self->builder->get_object('button-previous')
		->signal_connect(
			clicked =>
			\&on_clicked_button_previous_cb, $self );

	$self->builder->get_object('tts-window')->show_all;
	$self->update;
}

method speak( $text ) {
	$self->synth->speak($text);
}

fun on_clicked_button_play_cb( $button, $self ) {
	$self->playing( ! $self->playing );
	$self->builder->get_object('button-play')
		->set_label(
			  $self->playing
			? 'gtk-media-pause'
			: 'gtk-media-play'
		);
	$self->update;
}

method update {
	return unless defined $self->app->page_document_component;
	my $page_doc = $self->app->page_document_component;
	my $text = $page_doc->current_text_page;
	$self->builder->get_object('label-sentence-count')
		->set_text(
			"@{[ $page_doc->current_sentence_number + 1 ]} / @{[ scalar @$text ]}"
		);
	my $current_sentence_text =
		$text->[$page_doc->current_sentence_number]{sentence};
	$self->builder->get_object('tts-text')
		->get_buffer
		->set_text($current_sentence_text);
	if( $self->playing ) {
		$self->speak( $current_sentence_text );
		$self->choose_next_sentence;
	}
}

method num_of_sentences_on_page {
	my $page_doc = $self->app->page_document_component;
	my $text = $page_doc->current_text_page;
	return @{ $text };
}

fun on_clicked_button_previous_cb( $button, $self ) {
	$self->choose_previous_sentence;
}

fun on_clicked_button_next_cb( $button, $self ) {
	$self->choose_next_sentence;
}

method choose_previous_sentence() {
	my $page_doc = $self->app->page_document_component;
	if( $page_doc->current_sentence_number > 0 ) {
		$page_doc->current_sentence_number( $page_doc->current_sentence_number - 1 );
	} elsif( $page_doc->can_move_to_previous_page ) {
		$page_doc->set_current_page_back;
	}
}

method choose_next_sentence() {
	my $page_doc = $self->app->page_document_component;
	if( $page_doc->current_sentence_number < $self->num_of_sentences_on_page ) {
		$page_doc->current_sentence_number( $page_doc->current_sentence_number + 1 );
	} elsif( $page_doc->can_move_to_next_page ) {
		$page_doc->set_current_page_forward;
	}
}

sub _build_synth {
	my $engine;
	my $preferred_voice_name;
	if( $^O eq 'linux' ) {
		$engine = 'Festival';
		$preferred_voice_name = 'nitech_us_awb_arctic_hts';
	} elsif( $^O eq 'darwin' ) {
		$engine = "MacSpeech";
	} elsif( $^O eq 'MSWin32' ) {
		$engine = 'SAPI5';
		$preferred_voice_name = 'Microsoft Zira Desktop';
	}
	my @voices = Speech::Synthesis->InstalledVoices(engine => $engine);
	my @avatars = Speech::Synthesis->InstalledAvatars(engine => $engine);
	my $voice = ( first {
		$_->{name} eq $preferred_voice_name
	} @voices ) // $voices[-1];
	my %params = (
		engine   => $engine,
		avatar   => undef,
		language => $voice->{language},
		voice    => $voice->{id},
		async    => 0
	);
        my $ss = Speech::Synthesis->new( %params );
}


with qw(
	Renard::Curie::Component::Role::FromBuilder
	Renard::Curie::Component::Role::UIFileFromPackageName
	Renard::Curie::Component::Role::HasParentApp
);

1;
