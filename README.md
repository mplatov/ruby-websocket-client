# Ruby WebSocket Client

Implementation of WebSocket client in ruby to talk to WebSockets server. It was developed primarily as a tool to test basic protocol conformance of a WebSocket server.

This client supports [hybi-07 draft](http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-07). Older version of the protocol ([hixie draft-76](http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76)) is not supported.

The client includes some basic tests to check websocket framing, fragmentation and compression (more details in the spec folder).


## Subprotocols
The client assumes that the server under test support several subprotocols.
### protocols of [libwebsockets server](http://git.warmcat.com/cgi-bin/cgit/libwebsockets/)
* lws-mirror-protocol (copies any received packet to every connection also using this protocol, including the sender)
* dumb-increment-protocol (send incrementing ASCII string every 0.5 second)
* fraggle-protocol

### org.ietf [tests](http://www.ietf.org/mail-archive/web/hybi/current/msg06781.html)
* org.ietf.websocket.test-echo-assemble (echo messages after assembling all fragments)
* org.ietf.websocket.test-echo-fragment (echo frames randomly fragmented)
* org.ietf.websocket.test-produce (produce messages of random size and fragmentation)


Check out the contents of the /spec folder for usage examples.


# License

The MIT License - Copyright (c) 2011 Mikhail Platov