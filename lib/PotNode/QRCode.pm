package PotNode::QRCode;

use Mojo::Base -base;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use Mojo::File qw(path);
use Imager::QRCode;
use File::Temp qw(tempdir);
use Scalar::Util qw(blessed);
our $VERSION = '0.01';

has 'logo';
has text => '';
has tempdir => tempdir('qrcode_XXXX', TMPDIR => 1);
has file => sub { path($_[0]->tempdir . '/' . int(rand($_[0])) . '.png') };

sub qrcode {
  my ($self, $args) = (shift, ref($_[0]) ? $_[0] : (@_ % 2) ? $_[0] : {@_});
  return $self->{qrcode} if blessed($self->{qrcode});

  my $qrcode = {%{$self->{qrcode} || {}}, %{$args->{qrcode} // {}}};
  $qrcode->{size}          //= 10;
  $qrcode->{casesensitive} //= 1;
  $qrcode->{margin}        //= 1;
  $qrcode->{version}       //= 10;
  $qrcode->{level}         //= 'H';
  $qrcode->{mode} ||= '8-bit';
  my $text = $args->{text} ? $self->text($args->{text})->text : $self->text;

  #Error correction level should be "H" if we are going to
  # use a logo.
  Carp::croak("Please provide one of H|M|L|Q for 'level'")
    unless $qrcode->{level} =~ /^(H|M|L|Q)$/;
  Carp::croak("Please provide some value for 'text'")
    unless $text;

  if ($self->logo) {
    Carp::croak("'level' value should be 'H' if we need to put a logo in the middle!")
      if ($qrcode->{level} ||= 'H') ne 'H';
  }
  return $self->{qrcode} = Imager::QRCode::plot_qrcode($text, $qrcode);
}

# Resize logo to be small enough and compose it into the qrcode.
sub _paste_logo_in_qrcode($self) {
  my Imager $logo = $self->logo;
  return unless $logo;
  my $qrcode = $self->qrcode;

  #Resize logo to half of the QR code
  $logo =
    $logo->scale(xpixels => $qrcode->getwidth / 3, ypixels => $qrcode->getheight / 3);

  my $center = {
    x => $qrcode->getwidth / 2 - $logo->getwidth / 2,
    y => $qrcode->getheight / 2 - $logo->getheight / 2
  };

  # using "->compose" to get only the not-transparent layer :)! YAY1 success!
  $qrcode->compose(
    left => $center->{x},
    top  => $center->{y},
    src  => $logo
  );
}

sub to_png ($self, $path = '') {
  $self->_paste_logo_in_qrcode();
  $self->file(path($path)) if $path ne '';
  $self->qrcode->write(file => $self->file)
    or Carp::croak $self->qrcode->errstr;
  return $self;
}


sub to_png_base64($self, $path = '') {
  require MIME::Base64;
  my $bin = path($self->to_png($path)->file)->slurp();
  return 'data:image/png;base64,'.MIME::Base64::encode($bin);
}


=encoding utf8

=head1 NAME

Mojo::QRCode - generate fancy qrcodes!

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Here is how to generate an image with qrcode with a logo in the middle.

    use Mojo::QRCode;

    my $mqr = Mojo::QRCode->new(text=>'алабаланица', qrcode =>{...});
    my $base64_img_data = $mqr->to_png_base64();
    # or
    my $binary_img_data = $mqr->to_png->file->slurp();

=head1 ATTRIBUTES

Mojo::QRCode implements the following attributes.

=head2 logo

Logo image which will be placed in the middle of the fancy qrcode. Optional. The logo is
scaled down to half of the size of the qrcode image and put in the middle of it. See also
L<Imager::Transformations>.

  my $logo = Imager->new(file => $filename)
  or die Imager->errstr;
  $mqr->logo($logo);

=head2 text

Text that will be put in the code. By default we use C<version=10> and error correction
C<H> for generating the qrcode, which allows us to store up to 174 8-bit characters. This
should be enough even for UTF-8 text. Of course you can use UTF-8 text. See
L<https://en.wikipedia.org/wiki/QR_code#Storage>.

=head2 tempdir

Directory in C< $ENV{TMP} > where the file will be written.
The template is C<qrcode_XXXX>. You can use your own directory if you set this value.
The directory is not deleted on program shutdoun.

=head2 file

Filename in the L</tempdir> to which the image data will be written.
The file format will be chosen by the filename extension.
By default we use a PNG file, because it supports transparency
and allows us to put a logo with potentialy transparent parts.

=head1 SUBROUTINES/METHODS

=head2 new( qrcode =>{...}, ...)

Constructor for L<Mojo::QRCode>. Arguments can be C<logo, text, tempdir, file> and
C<qrcode>. C<qrcode> is a hash-reference which will be used for instantiating the
underlying L<Imager::QRCode>. Returns a new instance.

=head2 qrcode( text=>'up to 174 8-bit symbols' qrcode=>{...})

Instantiates L<Image::QRCode> and returns it.

Arguments: C<text, qrcode>. The arguments are optional. They can be passed to the
constructor too. By default this method will generate a "I<Version 10 QR Code, up to 174
char at H level, with 57X57 modules and plenty of Error-Correction to go around. Note that
there are additional tracking boxes>". See
L<https://en.wikipedia.org/wiki/QR_code#Storage>. Default values:

  $mqr->new(text=>'алабаланица')
    ->qrcode(
      size => 10,
      casesensitive => 1,
      margin => 1,
      version => 10,
      level => 'H',
      mode => '8-bit'
    );

=head2 to_png_base64

Returns a base 64 encoded representation of the binary png code which can be added to the
C<src> attribute of a n C<img> HTML tag or embedded as value in a JSON response.

  <img src="<%= Mojo::QRCode->new(text=>'алабаланица')->to_png_base64() %>"

  $c->render(json => {
    foo_img_src => Mojo::QRCode->new(text=>'алабаланица')->to_png_base64()
  });

=head2 to_png($path = '')

Writes the image to a PNG file specified by the C<$path> argument. If C<$path> argument is
not passed the image is written to a file in C<$ENV{TMP}>. You can get the file name using
C<$self-E<gt>file>. Returns C<self> on success or croaks otherwise.

=head1 AUTHOR

Краси Беров, C<< <k.berov at gmail.com> >>

=head1 BUGS

Maybe many.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Mojo::QRCode

You can also look for information at (NOT YET):

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojo-QRCode>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mojo-QRCode>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mojo-QRCode>

=item * Search CPAN

L<http://search.cpan.org/dist/Mojo-QRCode/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2017 Краси Беров.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1;    # End of Mojo::QRCode
