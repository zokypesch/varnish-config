<<<<<<< HEAD
# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "172.31.165.162";
    .port = "3000";
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
    .max_connections = 800;
}

# Only allow purging from specific IPs
acl purge {
    "localhost";
    "127.0.0.1";
    "10.0.0.10";
}

# This function is used when a request is send by a HTTP client (Browser) 
sub vcl_recv {
        # Normalize the header, remove the port (in case you're testing this on various TCP ports)
        set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

        # Allow purging from ACL
        if (req.method == "PURGE") {
                # If not allowed then a error 405 is returned
                if (!client.ip ~ purge) {
                        return(synth(405, "This IP is not allowed to send PURGE requests."));
                }
                # If allowed, do a cache_lookup -> vlc_hit() or vlc_miss()
                return (purge);
        }

        # Post requests will not be cached
        if (req.http.Authorization || req.method == "POST") {
                return (pass);
        }

        # --- WordPress specific configuration

        # Did not cache the RSS feed
        if (req.url ~ "/feed") {
                return (pass);
        }

        # Blitz hack
        if (req.url ~ "/mu-.*") {
                return (pass);
        }


        # Did not cache the admin and login pages
        if (req.url ~ "/wp-(login|admin)") {
                return (pass);
        }


        # Remove the "has_js" cookie
        set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");

        # Remove any Google Analytics based cookies
        set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");

        # Remove the Quant Capital cookies (added by some plugin, all __qca)
        set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");

        # Remove the wp-settings-1 cookie
        set req.http.Cookie = regsuball(req.http.Cookie, "wp-settings-1=[^;]+(; )?", "");

        # Remove the wp-settings-time-1 cookie
        set req.http.Cookie = regsuball(req.http.Cookie, "wp-settings-time-1=[^;]+(; )?", "");

        # Remove the wp test cookie
        set req.http.Cookie = regsuball(req.http.Cookie, "wordpress_test_cookie=[^;]+(; )?", "");

        # Are there cookies left with only spaces or that are empty?
        if (req.http.cookie ~ "^ *$") {
                    unset req.http.cookie;
        }

        # Cache the following files extensions 
        if (req.url ~ "\.(css|js|png|gif|jp(e)?g|swf|ico)") {
                unset req.http.cookie;
        }

        # Normalize Accept-Encoding header and compression
        # https://www.varnish-cache.org/docs/3.0/tutorial/vary.html
        if (req.http.Accept-Encoding) {
                # Do no compress compressed files...
                if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
                                unset req.http.Accept-Encoding;
                } elsif (req.http.Accept-Encoding ~ "gzip") {
                        set req.http.Accept-Encoding = "gzip";
                } elsif (req.http.Accept-Encoding ~ "deflate") {
                        set req.http.Accept-Encoding = "deflate";
                } else {
                        unset req.http.Accept-Encoding;
                }
        }

        # Check the cookies for wordpress-specific items
        if (req.http.Cookie ~ "wordpress_" || req.http.Cookie ~ "comment_") {
                return (pass);
        }
        if (!req.http.cookie) {
                unset req.http.cookie;
        }

        # --- End of WordPress specific configuration

        # Do not cache HTTP authentication and HTTP Cookie
        if (req.http.Authorization || req.http.Cookie) {
                # Not cacheable by default
                return (pass);
        }

        # Cache all others requests
        return (hash);
}

sub vcl_pipe {
        return (pipe);
}

sub vcl_pass {
        return (fetch);
=======
# Default backend definition.  Set this to point to your content server.
# all paths relative to varnish option vcl_dir

include "custom.backend.vcl";
include "custom.acl.vcl";

# Handle the HTTP request received by the client
sub vcl_recv {
    # shortcut for DFind requests
    if (req.url ~ "^/w00tw00t") {
        error 404 "Not Found";
    }

    # Serve objects up to 2 minutes past their expiry if the backend is slow to respond.
    set req.grace = 120s;

    if (req.restarts == 0) {
        if (req.http.X-Forwarded-For) {
            set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
    }

    # Normalize the header, remove the port (in case you're testing this on various TCP ports)
    set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

    # Allow purging
    if (req.request == "PURGE") {
        if (!client.ip ~ purge) {
            # Not from an allowed IP? Then die with an error.
            error 405 "This IP is not allowed to send PURGE requests.";
        }

        # If you got this stage (and didn't error out above), do a cache-lookup
        # That will force entry into vcl_hit() or vcl_miss() below and purge the actual cache
        return (lookup);
    }

    # Only deal with "normal" types
    if (req.request != "GET" &&
            req.request != "HEAD" &&
            req.request != "PUT" &&
            req.request != "POST" &&
            req.request != "TRACE" &&
            req.request != "OPTIONS" &&
            req.request != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }

    if (req.request != "GET" && req.request != "HEAD") {
        # We only deal with GET and HEAD by default
        return (pass);
    }

    # Some generic URL manipulation, useful for all templates that follow
    # First remove the Google Analytics added parameters, useless for our backend
    #if (req.url ~ "(\?|&)(utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=") {
    #    set req.url = regsuball(req.url, "&(utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "");
    #    set req.url = regsuball(req.url, "\?(utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "?");
    #    set req.url = regsub(req.url, "\?&", "?");
    #    set req.url = regsub(req.url, "\?$", "");
    #}

    # Strip hash, server doesn't need it.
    if (req.url ~ "\#") {
        set req.url = regsub(req.url, "\#.*$", "");
    }

    # Strip a trailing ? if it exists
    if (req.url ~ "\?$") {
        set req.url = regsub(req.url, "\?$", "");
    }

    # Some generic cookie manipulation, useful for all templates that follow
    # Remove the "has_js" cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");
    # Remove any Google Analytics based cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmctr=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmcmd.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmccn.=[^;]+(; )?", "");
    # Remove the Quant Capital cookies (added by some plugin, all __qca)
    set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");
    # Remove a ";" prefix, if present.
    set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
    # remove newrelic
    set req.http.Cookie = regsuball(req.http.Cookie, "NREUM=[^;]*", "");
    # remove ASP
    set req.http.Cookie = regsuball(req.http.Cookie, "ASP.NET_SessionId=[^;]*", "");

    # Are there cookies left with only spaces or that are empty?
    if (req.http.cookie ~ "^ *$") {
        unset req.http.cookie;
    }

    # Normalize Accept-Encoding header
    # straight from the manual: https://www.varnish-cache.org/docs/3.0/tutorial/vary.html
    if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
            # No point in compressing these
            remove req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unkown algorithm
            remove req.http.Accept-Encoding;
        }
    }

    # Remove all cookies for static files
    if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|mp[34]|pdf|png|rar|rtf|swf|tar|tgz|txt|wav|woff|xml|zip)(\?.*)?$") {
        unset req.http.Cookie;
        return (lookup);
    }

    # Send Surrogate-Capability headers to announce ESI support to backend
    set req.http.Surrogate-Capability = "abc=ESI/1.0";

    # Include custom vcl_recv logic
    include "custom.recv.vcl";

    if(req.url ~ "/(ajaxcontroller|edit|selftest)" || req.url ~ "/(admin|login|monitor)" || req.url ~ "/wp-(login|admin)"){
        # Not cacheable by default
        return (pass);
    }

    if (req.http.Authorization) {
        # Not cacheable by default
        return (pass);
    }

    return (lookup);
}

sub vcl_pipe {
    # Note that only the first request to the backend will have
    # X-Forwarded-For set.  If you use X-Forwarded-For and want to
    # have it set for all requests, make sure to have:
    # set bereq.http.connection = "close";
    # here.  It is not set by default as it might break some broken web
    # applications, like IIS with NTLM authentication.

    set bereq.http.Connection = "Close";
    return (pipe);
}

sub vcl_pass {
    return (pass);
>>>>>>> 4bb489052fa3defc962c5748c7499c94284d3ab2
}

# The data on which the hashing will take place
sub vcl_hash {
<<<<<<< HEAD
        hash_data(req.url);
        if (req.http.host) {
             hash_data(req.http.host);
        } else {
             hash_data(server.ip);
        }

        # If the client supports compression, keep that in a different cache
        if (req.http.Accept-Encoding) {
             hash_data(req.http.Accept-Encoding);
        }

        return (lookup);
}

# This function is used when a request is sent by our backend (Nginx server)
sub vcl_backend_response {
        # Remove some headers we never want to see
        unset beresp.http.Server;
        unset beresp.http.X-Powered-By;

        # For static content strip all backend cookies
        if (bereq.url ~ "\.(css|js|png|gif|jp(e?)g)|swf|ico") {
                unset beresp.http.cookie;
        }

        # Only allow cookies to be set if we're in admin area
        if (beresp.http.Set-Cookie && bereq.url !~ "^/wp-(login|admin)") {
                unset beresp.http.Set-Cookie;
        }

        # don't cache response to posted requests or those with basic auth
        if ( bereq.method == "POST" || bereq.http.Authorization ) {
                set beresp.uncacheable = true;
                set beresp.ttl = 120s;
                return (deliver);
        }

        # don't cache search results
        if ( bereq.url ~ "\?s=" ){
                set beresp.uncacheable = true;
                set beresp.ttl = 120s;
                return (deliver);
        }

        # only cache status ok
        if ( beresp.status != 200 ) {
                set beresp.uncacheable = true;
                set beresp.ttl = 120s;
                return (deliver);
        }

        # A TTL of 24h
        set beresp.ttl = 24h;
        # Define the default grace period to serve cached content
        set beresp.grace = 30s;

        return (deliver);
=======
    hash_data(req.url);

    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }

    # hash cookies for object with auth
    if (req.http.Cookie) {
        hash_data(req.http.Cookie);
    }

    if (req.http.Authorization) {
        hash_data(req.http.Authorization);
    }

    # If the client supports compression, keep that in a different cache
    if (req.http.Accept-Encoding) {
        hash_data(req.http.Accept-Encoding);
    }

    return (hash);
}

sub vcl_hit {
    # Allow purges
    if (req.request == "PURGE") {
        purge;
        error 200 "purged";
    }

    return (deliver);
}

sub vcl_miss {
    # Allow purges
    if (req.request == "PURGE") {
        purge;
        error 200 "purged";
    }

    return (fetch);
}

# Handle the HTTP request coming from our backend
sub vcl_fetch {
    # Include custom vcl_fetch logic
    include "custom.fetch.vcl";

    # Serve objects up to 2 minutes past their expiry if the backend is slow to respond.
    set beresp.grace = 2m;

    # Default cache time, 2 minutes
    #set beresp.ttl = 5m;

    # Parse ESI request and remove Surrogate-Control header
    if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
        unset beresp.http.Surrogate-Control;
        set beresp.do_esi = true;
    }

    if (beresp.http.X-Reverse-Proxy-TTL) {
        C{
            char *ttl;
            ttl = VRT_GetHdr(sp, HDR_BERESP, "\024X-Reverse-Proxy-TTL:");
            VRT_l_beresp_ttl(sp, atoi(ttl));
        }C
        unset beresp.http.X-Reverse-Proxy-TTL;
    }

    # If the request to the backend returns a code is 5xx, restart the loop
    # If the number of restarts reaches the value of the parameter max_restarts,
    # the request will be error'ed.  max_restarts defaults to 4.  This prevents
    # an eternal loop in the event that, e.g., the object does not exist at all.
    if (beresp.status >= 500 && beresp.status <= 599){
        return(restart);
    }

    # Enable cache for all static files
    if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|mp[34]|pdf|png|rar|rtf|swf|tar|tgz|txt|wav|woff|xml|zip)(\?.*)?$") {
        unset beresp.http.set-cookie;
        set beresp.ttl = 1h;
    }

    # Varnish determined the object was not cacheable
    if (beresp.ttl <= 0s) {
        set beresp.http.X-Cacheable = "NO:Not Cacheable";

    # You don't wish to cache content for logged in users
    } elsif (req.http.Cookie ~ "(UserID|_session|JSESSIONID)") {
        set beresp.http.X-Cacheable = "NO:Got Session";
        return(hit_for_pass);

    # You are respecting the Cache-Control=private header from the backend
    } elsif (beresp.http.Cache-Control ~ "private") {
        set beresp.http.X-Cacheable = "NO:Cache-Control=private";
        return(hit_for_pass);

    # Varnish determined the object was cacheable
    } else {
        set beresp.http.X-Cacheable = "YES";
        set beresp.http.X-TTL = beresp.ttl;
    }

    return (deliver);
>>>>>>> 4bb489052fa3defc962c5748c7499c94284d3ab2
}

# The routine when we deliver the HTTP request to the user
# Last chance to modify headers that are sent to the client
sub vcl_deliver {
<<<<<<< HEAD
        if (obj.hits > 0) {
                set resp.http.X-Cache = "cached";
        } else {
                set resp.http.x-Cache = "uncached";
        }

        # Remove some headers: PHP version
        unset resp.http.X-Powered-By;

        # Remove some headers: Apache version & OS
        unset resp.http.Server;

        # Remove some heanders: Varnish
        unset resp.http.Via;
        unset resp.http.X-Varnish;

        return (deliver);
}

sub vcl_init {
        return (ok);
}

sub vcl_fini {
        return (ok);
}

=======
    if (obj.hits > 0) {
        set resp.http.X-Cache-Hits = obj.hits;
        set resp.http.X-Cache = "cached";
    } else {
        set resp.http.X-Cache = "uncached";
    }

    # Remove some headers: PHP version
    unset resp.http.X-Powered-By;
    # Remove some headers: Apache version & OS
    unset resp.http.Server;
    unset resp.http.X-Drupal-Cache;
    unset resp.http.X-Varnish;
    unset resp.http.Via;
    unset resp.http.Link;

    return (deliver);
}

sub vcl_error {
    if (obj.status >= 500 && obj.status <= 599 && req.restarts < 4) {
        # 4 retry for 5xx error
        #return(restart);
        include "conf.d/error.vcl";
    } elsif (obj.status >= 400 && obj.status <= 499 ) {
        # use 404 error page for 4xx error
        include "conf.d/error-404.vcl";
    } elsif (obj.status <= 200 || obj.status >= 299 ) {
        # for other errors (not 5xx, not 4xx and not 2xx)
        include "conf.d/error.vcl";
    }
    return (deliver);
}

sub vcl_init {
    return (ok);
}

sub vcl_fini {
    return (ok);
}
>>>>>>> 4bb489052fa3defc962c5748c7499c94284d3ab2
