# This is a basic VCL configuration file for varnish. 
# Copyright by Shaohaiyang at 53kf inc.
# Contact email: shaohaiyang@gmail.com
# 
# Default backend definition.  Set this to point to your content server.

backend h_54geke_com_1 {			# ProxyList
 	.host="127.0.0.1";		# ProxyList
 	.port="81";			# ProxyList
 	.connect_timeout=300s;		# ProxyList
 	.first_byte_timeout=300s;	# ProxyList
 	.between_bytes_timeout=300s;	# ProxyList
 }					# ProxyList

director geke client {			# ProxyList
	{ .backend=h_54geke_com_1; .weight=3;}	# ProxyList
}					# ProxyList

##############################################################

acl denyzone {
        "10.1.1.5";
        "10.0.2.5";
        "10.10.1.3";
}

acl purge {
       "localhost";
       "127.0.0.1";
}

# 
# Below is a commented-out copy of the default VCL logic.  If you
# redefine any of these subroutines, the built-in logic will be
# appended to your code.
# 
sub vcl_recv {
	if ( req.http.user-agent ~ "^$" 		# blacklist
		|| req.url ~ "fuck" 			# blacklist
		|| req.http.referer ~ "fuck" 		# blacklist
		|| req.http.user-agent ~ "xxxx" 	# blacklist
		|| client.ip == "192.168.0.13" 		# blacklist
	) {						# blacklist
		error 403 "Not Allowed.";		# blacklist
	}						# blacklist

	if ( client.ip ~ denyzone ) {
		error 403 "Not Allowed.";
	}

     if (req.restarts == 0) {
       if (req.http.x-forwarded-for) {
           set req.http.X-Forwarded-For =
               req.http.X-Forwarded-For + ", " + client.ip;
       } else {
           set req.http.X-Forwarded-For = client.ip;
       }
     }

# Don't serve cached pages to logged in users
	#if ( req.url ~ "vaultpress=true" 
	#	|| req.url ~ "^/$" 
	#	|| req.url ~ "sso_verify" 
	#	|| req.url ~ "account"
	#	|| req.url ~ "passport" 
	#) {
	#	return (pass);
	#}
	if ( req.http.cookie ~ "wordpress_logged_in" ) {
		return (lookup);
	}
#unset req.http.cookie;  # if you had used cookie save session id,unset please
	set req.grace = 5m;

	if (req.request == "BAN") {
		if (client.ip !~ purge) {
			error 405 "Not allowed.";
			}
		ban("req.url == " + req.url);
		error 200 "Ban added";
	}

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

######################################################################################

# Added by geminis,the function is forward jsp request to java comet server
	if (req.http.host~"^(www).?54geke.com$"){			# ProxyList
 		set req.backend=geke;				# ProxyList
 		if (req.request != "GET" && req.request != "HEAD") {	# ProxyList
 			return (pipe);				# ProxyList
 		}						# ProxyList
 		if(req.url ~ "\.(php|jsp)($|\?)") {			# ProxyList
 			return (pass);				# ProxyList
 		}						# ProxyList
 		else {						# ProxyList
 			return (lookup);			# ProxyList
 		}						# ProxyList
 	}							# ProxyList
 }

sub vcl_pipe {
	set bereq.http.connection = "close";
	return (pipe);
 }
 
sub vcl_pass {
     return (pass);
 }
 
sub vcl_hash {
     hash_data(req.url);
     if (req.http.host) {
         hash_data(req.http.host);
     } else {
         hash_data(server.ip);
     }
     return (hash);
 }

sub vcl_hit {
     if (req.request == "PURGE") {
         set obj.ttl = 0s;
         error 200 "Purged.";
     }

     return (deliver);
 }

sub vcl_miss {
    if (req.request == "PURGE") {
         error 404 "Not in cache.";
     }
     return (fetch);
 }

sub vcl_error {
     set obj.http.Content-Type = "text/html; charset=utf-8";
     set obj.http.Retry-After = "5";
     synthetic {"
 <?xml version="1.0" encoding="utf-8"?>
 <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
 <html>
   <head>
     <title>"} + obj.status + " " + obj.response + {"</title>
   </head>
   <body>
     <h1>Error "} + obj.status + " " + obj.response + {"</h1>
     <p>"} + obj.response + {"</p>
     <h3>Guru Meditation:</h3>
     <p>XID: "} + req.xid + {"</p>
     <hr>
     <p>Varnish cache server</p>
   </body>
 </html>
 "};
     return (deliver);
 }

sub vcl_init {
       return (ok);
 }

sub vcl_fini {
       return (ok);
 }

sub vcl_fetch {
# Keep objects 1 hour in cache past their expiry time. This allows varnish
# to server stale content if the backend is sick.
	set beresp.grace = 1h;
	set beresp.http.Cache-Control = "max-age=86400";
	set beresp.ttl = 1d;

     if (beresp.ttl <= 0s ||
         beresp.http.Set-Cookie ||
         beresp.http.Vary == "*") {
               /*
                * Mark as "Hit-For-Pass" for the next 2 minutes
                */
               set beresp.ttl = 120s;
               return (hit_for_pass);
     }
     return (deliver);
 }

sub vcl_deliver {
	set resp.http.X-Hits = obj.hits;
	if(obj.hits>0){
		set resp.http.X-Cache="HIT";
	}
	else{
		set resp.http.X-Cache="MISS";
	}
	return (deliver);
}
