package Kwiki::FetchRSS;
use strict;
use warnings;
use Kwiki::Plugin '-Base';
use Kwiki::Installer '-base';

our $VERSION = '0.06';

const class_id    => 'fetchrss';
const class_title => 'Fetch RSS';
const config_file => 'fetchrss.yaml';
const css_file    => 'fetchrss.css';
field 'cache';
field 'error';
field 'expire';

sub register {
    my $registry = shift;
    $registry->add( wafl => fetchrss => 'Kwiki::FetchRSS::Wafl' );
}

sub cache_dir {
    $self->plugin_directory;
}

sub get_content {
    my $url = shift;
    my $content;

    require LWP::UserAgent;
    my $ua  = LWP::UserAgent->new();
    $ua->timeout($self->hub->config->fetchrss_ua_timeout);
    if ( $self->hub->config->fetchrss_proxy ne '' ) {
        $ua->proxy([ 'http' ], $self->hub->config->fetchrss_proxy);
    }
    my $response = $ua->get($url);
    if ($response->is_success()) {
        $content  = $response->content();
        if (length($content)) {
            $self->cache->set( $url, $content, $self->expire );
        } else {
            $self->error('zero length response');
        }
    } else {
        $self->error($response->status_line);
    }
    return $content;
}

sub setup_cache {
    require Cache::FileCache;
    $self->cache(Cache::FileCache->new( {
         namespace   => $self->class_id,
         cache_root  => $self->cache_dir,
         cache_depth => 1,
         cache_umask => 002,
    } ));
}

sub get_cached_result {
    my $name  = shift;
    return($self->cache->get($name));
}

sub get_rss {
    my ($url, $expire) = @_;

    require XML::RSS;

    $self->expire($expire
        ? $expire
        : $self->hub->config->fetchrss_default_expire()
    );
    $self->setup_cache;

    my $content = $self->get_cached_result($url);
    if ( !defined($content) or !length($content) ) {
        $content = $self->get_content($url);
    }

    if (defined($content) and length($content)) {
        my $rss = XML::RSS->new();
        # XXX needs to be an eval here, sometimes the parse
        # make poop on bad input
        eval {
            $rss->parse($content);
        };
        return $rss unless $@;
        $self->error('xml parser error');
    }
    return {error => $self->error};
}

package Kwiki::FetchRSS::Wafl;
use Spoon::Formatter;
use base 'Spoon::Formatter::WaflPhrase';

sub to_html {
    my ($url, $full, $expire) = split(/,?\s+/, $self->arguments);
    $self->use_class('fetchrss');
    my $rss = $self->fetchrss->get_rss($url, $expire);
    $self->hub->template->process('fetchrss.html', full => $full, %$rss);
}


1;

package Kwiki::FetchRSS;

1;

__DATA__

=head1 NAME

Kwiki::FetchRSS - Wafl Phrase for including RSS feeds in a Kwiki Page

=head1 DESCRIPTION

  {fetchrss <rss url> [full] [expire]}

Kwiki::FetchRSS retrieves and caches an RSS feed from a blog, news 
site, wiki, wherever and presents it in a Kwiki page. It can optionally
display the description text for each item, or just the headline. Cache
expiration times for each phrase may be set, or a default can be set
in the configuration file fetrchrss.yaml.

You can see Kwiki::FetchRSS in action at http://www.burningchrome.com/wiki/

This code needs some feedback to find its way in life.

=head1 AUTHORS

Alex Goller
Chris Dent <cdent@burningchrome.com>

=head1 SEE ALSO

L<Kwiki>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005, the authors

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__template/tt2/fetchrss.html__
<!-- BEGIN fetchrss.html -->
<div class="fetchrss_box">
<div class="fetchrss_titlebox">
[% IF error %]
Error: [% error %]
[% END %]
[% IF image.link && image.url %]
<center>
<a href="[% image.link %]">
 <img src="[% image.url %]"
  alt="[% image.title %]"
  border="0"
  [% IF image.width %]
   width="[% image.width %]"
  [% END %]
  [% IF image.height %]
   heigth="[% image.heigth %]"
  [% END %]
[% END %]

[% IF channel.title %]
 <div class="fetchrss_title">
   <a href="[% channel.link %]">[% channel.title %]</a></h3>
 </div>
[% END %]
</center>
</div>

[% FOREACH item = items %]
 <div class="fetchrss_item">
     <a href="[% item.link %]">[% item.title %]</a><br />
   [% IF full && item.description %]
     <blockquote class="fetchrss_description">
         [% item.description %]
     </blockquote>
   [% END %]
 </div>
[% END %]

[% IF channel.copyright %]
<div class="fetchrss_titlebox">
<sub>[% channel.copyright %]</sub>
</div>
[% END %]
</div>
<!-- END fetchrss.html -->
__config/fetchrss.yaml__
fetchrss_proxy:
fetchrss_ua_timeout: 30
fetchrss_default_expire: 1h
__css/fetchrss.css__
.fetchrss_box {
  clear: both;
  margin-top: 5px;
  margin-left: 5px;
  border: 1px dashed #aaaaaa;
  background: #dddddd;
  font-family: Arial,Helvetica,Verdana,sans-serif;
}
.fetchrss_titlebox {
  background: #ffffff;
  padding-bottom: 5px;
  padding-top: 5px;
}
.fetchrss_title { font-weight: bold; font-size: large;}
.fetchrss_item { padding-left: 5px; }
.fetchrss_description { font-size: smaller; }

