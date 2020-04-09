# stream big file, add missing extention below
if (req.url ~ "\.(avi|deb|tar|gz|rar|iso|img|dmg|mkv|zip)$") {
    set beresp.do_stream = true;
    set beresp.ttl = 1d;
}

#if (req.http.Host == "my-wp1.localhost" || req.http.Host == "my-wp2.localhost") {
#    # Since this is a Wordpress setup, the Wordpress-specific Fetch
#    include "conf.d/fetch/wordpress.vcl";
#} elsif (req.http.Host == "my-drupal1.localhost" || req.http.Host == "my-drupal2.localhost") {
#    # Include the Drupal 7 specific VCL
#    include "conf.d/fetch/drupal7.vcl";
#}
