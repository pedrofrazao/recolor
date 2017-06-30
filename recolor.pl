#!/usr/bin/env perl

use warnings;
use strict;

use Data::Dumper;
use List::MoreUtils qw/first_value/;
use Getopt::Long;
use Term::ANSIColor;
use Config::Tiny;
use FindBin;
$|=1;

my $__debug = 0;
my @mre = ();
my @mignore = ();
my $csession;

my $default_color = q{yellow};


init();
main_loop();
exit;

sub main_loop {
 LOOP_LINE:
  while( my $line = <STDIN> ) {
    my $new_line = match_check( $line, \&print_with_color );
    print $new_line if defined $new_line;
  }
}

sub init {
  my $conf_file;
  my @t_mre;
  GetOptions ("c=s" => \@t_mre,
              "debug" => \$__debug,
              "v=s" => \@mignore,
              "conf=s" => \$conf_file,
              "session=s" => \$csession,
             );

  map { __parse_line( \@mre, $_ ) } @t_mre;

  if( $#mre == -1 ) {
    ## no regex, try to read from config file
    @mre = __load_from_config_file( $conf_file );
  }
}

sub match_check {
  my ( $line, $cb ) = @_;

 LOOP_RE:
  for my $re ( @mre ) {
    my @match = ();
    @match = $line =~ qr/$re->{regexp}/smx;
    if( ! defined $re->{regexp} ) {
      warn Dumper $re;
      die;
    }
    next LOOP_RE if( $#match == -1 );

    ## matched
    if( $re->{action} eq q{ignore} ) {
      warn( colored(qq{skip with $re->{regexp}},q{bold blue}), colored(qq{ - $line},q{ansi6} ) )
        if $__debug;
      return;
    }

    if( $re->{action} eq q{color} ) {
      warn( colored(qq{match with $re->{regexp}},q{bold blue}), qq{\n} )
        if $__debug;

      $line = $cb->( color => $re->{color},
                     line => [ $`, join(q{},@match) , $' ] );
      next LOOP_RE;
    }
    warn( qq{unknown actino $re->{action}, ignored} );
  }
  return $line;
}

sub print_with_color {
  my ( %args ) = @_;
  my $color = $args{color};
  my $line = $args{line};

  my $new_line = q{};

  $new_line = sprintf( q{%s%s%s}, $line->[0],
                       colored($line->[1], $color),
                       $line->[2] );

  return $new_line;
}

sub __load_from_config_file {
  my ( $c_file ) = @_;
  my @res = ();

  if( ! defined $c_file ) {
    my @c_files = ();
    push( @c_files,
          map { $_.q{/.recolor} } ( $FindBin::Bin, $ENV{HOME} )
        );
    $c_file = first_value { -r $_ } @c_files;
  }

  if( ! defined $c_file ) {
    warn(qq{can't load configuration file\n});
    return @res;
  }

  ## load from file
  my $config = Config::Tiny->read( $c_file );
  $default_color = $config->{_}->{default_color} || $default_color;
  my $session = $csession || $config->{_}->{default_session};

  die( qq{can't select default session on the config file, $c_file\n} )
    unless defined $session;

  my @action_lines = sort { $a cmp $b } ( keys %{$config->{$session} } );

 LOOP_STR:
  for my $nline ( @action_lines ) {
    my $str = $config->{$session}{ $nline } || q{};
    __parse_line ( \@res,  $str );
  }

  print Dumper \@res if $__debug;

  return @res;
}


sub __parse_line {
  my ( $res, $str ) = @_;

  my ($action) = $str =~ m{\A (\S+) }smx;

  if( $action eq q{ignore}
      or $action eq q{dcolor} ) {
    # only 1 arg - the regexp
    my ( $regexp ) = $str =~ m{\A \S+ \s+ (.*)\Z}smx;
    push( @$res,
          {
           action => ( $action eq q{dcolor} ? q{color} : $action ),
           regexp => $regexp,
           color => $default_color,
          } );
    return;
  }

  if( $action eq q{color} ) {
    # 2 args
    my ( $color, $regexp ) = $str =~ m{\A \S+ \s+ ( \S+ ) \s+ (.*) \Z}smx;
    push( @$res,
          {
           action => $action,
           regexp => $regexp,
           color => $color,
          } );
    return;
  }

  return;
}
