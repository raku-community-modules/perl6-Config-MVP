use v6;

unit module Config::MVP;

grammar MVP {
    token TOP      { 
                        ^
                        <.eol>*
                        <toplevel>?
                        <sections>* 
                        <.eol>*
                        $
                   }
    token toplevel { <keyval>* }
    token sections { <header> <keyval>* }
    token header   { ^^ \h* '[' ~ ']' $<text>=<-[ \] \n ]>+ \h* <.eol>+ }
    token keyval   { ^^ \h* <key> \h* '=' \h* <value>? \h* <.eol>+ }
    regex key      { <![\[]> <-[;=]>+ }
    regex value    { [ <![;]> \N ]+ }
    # TODO: This should be just overriden \n once Rakudo implements it
    token eol      { [ ';' \N+ ]? \n }
}

class MVP::Actions {
    method TOP ($/) { 
        my %hash = $<sections>».made;
        %hash<_> = pairs-to-hash( $<toplevel>.made ) if $<toplevel>.?made;
        make %hash;
    }
    method toplevel ($/) { make $<keyval>».made }
    method sections ($/) { make $<header><text>.Str => pairs-to-hash( $<keyval>».made ) }
    # TODO: The .trim is useless, <!after \h> should be added to key regex,
    # once Rakudo implements it
    method keyval ($/) {
        make Pair.new(
            key => $<key>.Str.trim,
            value => $<value>.defined ?? $<value>.Str.trim !! '',
        )
    }

    sub pairs-to-hash (@pairs) {
        my %h;
        for @pairs -> $p {
            if %h{ $p.key }:exists {
                if %h{ $p.key } ~~ Array {
                    %h{ $p.key }.append: $p.value;
                }
                else {
                    %h{ $p.key } = [ %h{ $p.key }, $p.value ];
                }
            }
            else {
                %h{ $p.key } = $p.value;
            }
        }
        return %h;
    }
}

our sub parse (Str $string) {
    MVP.parse( $string, :actions( MVP::Actions.new ) ).made;
}

our sub parse-file (Str $file) {
    MVP.parsefile( $file, :actions( MVP::Actions.new ) ).made;
}

=begin pod

=NAME

Config::MVP - parse .ini configuration files with repeated keys

=SYNOPSIS

    use Config::MVP;
    my %hash = Config::MVP::parse_file('config.ini');
    #or
    %hash = Config::MVP::parse($file_contents);
    say %hash<_><root_property_key>;
    say %hash<section><in_section_key>;

=DESCRIPTION

This module provides 2 functions: C<parse> and C<parse-file>, both taking one
C<Str> argument, where C<parse-file> is just parse(slurp $file).

Both subs return the same hash, where the keys are section names and the
values are in turn hashes themselves. Each section contains key/value pairs
matching each key/value pair in the parsed content. If a key appears more than
once then the value is an array.

The top level section has the key C<_> in the hash returned from parsing.

This content:

    name   = Config-MVP
    author = Dave Rolsky <autarch@urth.org>
    author = Tadeusz “tadzik” Sośnierz
    author = Nobuo Danjou

    [AutoPrereqs]
    skip = T::Internal
    skip = Optional

would result in the following hash:

    {
        _ => {
            name   => 'Config-MVP',
            author => [
                q{Dave Rolsky <autarch@urth.org>},
                q{Tadeusz “tadzik” Sośnierz},
                q{Nobuo Danjou},
            ],
        },
        AutoPrereqs => {
            skip => [ 'T::Internal', 'Optional' ],
        },
    }

Note that all values are currently parsed as strings, but this may change in
the future to be a little smarter about numbers and booleans.

=end pod

# vim: ft=perl6
