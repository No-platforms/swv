vcl 4.1;

backend wordpress {
        .host = "172.22.222.11";
        .port = "80";
        .connect_timeout = 10s;
        .first_byte_timeout = 50s;
        .between_bytes_timeout = 60s;
        #.last_byte_timeout = 200s;
        #.port = "443";
        #.ssl = 1;                              # Turn on SSL support
        #.ssl_sni = 1;                  # Use SNI extension  (default: 1)
        #.ssl_verify_peer = 1;  # Verify the peer's certificate chain (default: 1)
        #.ssl_verify_host = 1;  # Verify the host name in the peer's certificate (default: 0)
}

sub vcl_recv {
                # Pass Requests for Login Pages
                if (req.url ~ "^/wp-(login|admin|comments-post).php") {
                set req.backend_hint = wordpress;
                return (pass);
            }

                # Disable Caching for Logged-In Users
            if (req.http.Cookie ~ "wordpress_logged_in_") {
                return (pass);
            }
                        set req.backend_hint = wordpress;
                        return (hash);

}

sub vcl_backend_response {

        if (beresp.status >= 500) {
            # Do not cache server errors
            set beresp.ttl = 0s;
            set beresp.grace = 1h;
            return (deliver);
        }

        # Ensure that Varnish does not strip out these cookies for login-related requests
        if ("^/wp-(login|admin|comments-post).php") {
                set beresp.uncacheable = true;
                set beresp.ttl = 0s;
                return (deliver);
        }

    if(beresp.http.Vary) {
        set beresp.http.Vary = beresp.http.Vary + ", X-Forwarded-Proto";
    } else {
        set beresp.http.Vary = "X-Forwarded-Proto";
    }
        if (bereq.url ~ "^/") {
        set beresp.grace = 24h;
    }
    return (deliver);
}

sub vcl_backend_error {
   set beresp.ttl = 0s;
   set beresp.grace = 1h;
   return (deliver);
}


sub vcl_hit {
        set req.http.x-cache = "hit";
}

sub vcl_miss {
        set req.http.x-cache = "miss";
}

sub vcl_pass {
        set req.http.x-cache = "pass";
}

sub vcl_pipe {
        set req.http.x-cache = "pipe uncacheable";
}

sub vcl_synth {
        set req.http.x-cache = "synth synth";
}

sub vcl_deliver {
        if (obj.uncacheable) {
                set req.http.x-cache = req.http.x-cache + " uncacheable" ;
        } else {
                set req.http.x-cache = req.http.x-cache + " cached" ;
        }
        # uncomment the following line to show the information in the response
        set resp.http.x-cache = req.http.x-cache;
        unset resp.http.x-frame-options;
        unset resp.http.referrer-policy;
}