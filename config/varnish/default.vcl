# This is a basic VCL configuration file for varnish.  See the vcl(7)
# man page for details on VCL syntax and semantics.
#
# Default backend definition.  Set this to point to your content
# server.
#
backend default {
    .host = "ghost";
    .port = "2368";
}


sub vcl_recv {
    # Fix the domain if the www is not present
    if (!(req.http.host ~ "\.jeffreyharrell\.com$")) {
        set req.http.host = "www.jeffreyharrell.com";
        error 750 "http://" + req.http.host + req.url;
    }

    # If the client uses shift-F5, get (and cache) a fresh copy. Nice for
    # systems without content invalidation. Big sites will want to disable
    # this.
    if (req.http.cache-control ~ "no-cache") {
        set req.hash_always_miss = true;
    }

    set req.http.x-pass = "false";
    # TODO: I haven't seen any urls for logging access. When the
    # analytics parts of ghost are done, this needs to be added in the
    # exception list below.
    if (req.url ~ "^/(api|signout)") {
        set req.http.x-pass = "true";
    } elseif (req.url ~ "^/ghost" && (req.url !~ "^/ghost/(img|css|fonts)")) {
        set req.http.x-pass = "true";
    }

    if (req.http.x-pass == "true") {
        return(pass);
    }

    unset req.http.cookie;
}


sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }

    remove resp.http.Via;
    remove resp.http.X-Whatever;
    remove resp.http.X-Powered-By;
    remove resp.http.X-Varnish;
    remove resp.http.Age;
    remove resp.http.Server;
	remove resp.http.Cacheable;

	set resp.http.X-Powered-By = "Awesomeness";

}


sub vcl_fetch {
    # Only modify cookies/ttl outside of the management interface.
    if (req.http.x-pass != "true") {
        unset beresp.http.set-cookie;

        if (beresp.status < 500 && beresp.ttl <= 0s) {
            set beresp.ttl = 2m;
        }
    }

#    # Varnish determined the object was not cacheable
#    if (beresp.ttl <= 0s) {
#        set beresp.http.X-Cacheable = "NO:Not Cacheable";
#
#    # You don't wish to cache content for logged in users
#    } elsif (req.http.Cookie ~ "(UserID|_session)") {
#        set beresp.http.X-Cacheable = "NO:Got Session";
#        return(hit_for_pass);
#
#    # You are respecting the Cache-Control=private header from the backend
#    } elsif (beresp.http.Cache-Control ~ "private") {
#        set beresp.http.X-Cacheable = "NO:Cache-Control=private";
#        return(hit_for_pass);
#
#    # Varnish determined the object was cacheable
#    } else {
#        set beresp.http.X-Cacheable = "YES";
#    }

    return(deliver);
}


sub vcl_error {
    if (obj.status == 750) {
        set obj.http.Location = obj.response;
        set obj.status = 301;

        return(deliver);
    }
}


#
# Below is a commented-out copy of the default VCL logic.  If you
# redefine any of these subroutines, the built-in logic will be
# appended to your code.
# sub vcl_recv {
#     if (req.restarts == 0) {
# 	if (req.http.x-forwarded-for) {
# 	    set req.http.X-Forwarded-For =
# 		req.http.X-Forwarded-For + ", " + client.ip;
# 	} else {
# 	    set req.http.X-Forwarded-For = client.ip;
# 	}
#     }
#     if (req.request != "GET" &&
#       req.request != "HEAD" &&
#       req.request != "PUT" &&
#       req.request != "POST" &&
#       req.request != "TRACE" &&
#       req.request != "OPTIONS" &&
#       req.request != "DELETE") {
#         /* Non-RFC2616 or CONNECT which is weird. */
#         return (pipe);
#     }
#     if (req.request != "GET" && req.request != "HEAD") {
#         /* We only deal with GET and HEAD by default */
#         return (pass);
#     }
#     if (req.http.Authorization || req.http.Cookie) {
#         /* Not cacheable by default */
#         return (pass);
#     }
#     return (lookup);
# }
#
# sub vcl_pipe {
#     # Note that only the first request to the backend will have
#     # X-Forwarded-For set.  If you use X-Forwarded-For and want to
#     # have it set for all requests, make sure to have:
#     # set bereq.http.connection = "close";
#     # here.  It is not set by default as it might break some broken web
#     # applications, like IIS with NTLM authentication.
#     return (pipe);
# }
#
# sub vcl_pass {
#     return (pass);
# }
#
# sub vcl_hash {
#     hash_data(req.url);
#     if (req.http.host) {
#         hash_data(req.http.host);
#     } else {
#         hash_data(server.ip);
#     }
#     return (hash);
# }
#
# sub vcl_hit {
#     return (deliver);
# }
#
# sub vcl_miss {
#     return (fetch);
# }
#
# sub vcl_fetch {
#     if (beresp.ttl <= 0s ||
#         beresp.http.Set-Cookie ||
#         beresp.http.Vary == "*") {
# 		/*
# 		 * Mark as "Hit-For-Pass" for the next 2 minutes
# 		 */
# 		set beresp.ttl = 120 s;
# 		return (hit_for_pass);
#     }
#     return (deliver);
# }
#
# sub vcl_deliver {
#     return (deliver);
# }
#
# sub vcl_error {
#     set obj.http.Content-Type = "text/html; charset=utf-8";
#     set obj.http.Retry-After = "5";
#     synthetic {"
# <?xml version="1.0" encoding="utf-8"?>
# <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
#  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
# <html>
#   <head>
#     <title>"} + obj.status + " " + obj.response + {"</title>
#   </head>
#   <body>
#     <h1>Error "} + obj.status + " " + obj.response + {"</h1>
#     <p>"} + obj.response + {"</p>
#     <h3>Guru Meditation:</h3>
#     <p>XID: "} + req.xid + {"</p>
#     <hr>
#     <p>Varnish cache server</p>
#   </body>
# </html>
# "};
#     return (deliver);
# }
#
# sub vcl_init {
# 	return (ok);
# }
#
# sub vcl_fini {
# 	return (ok);
# }
