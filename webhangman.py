#!/usr/bin/env python3

import http.server
import sqlite3
import json

CONFIG = {
	'addr' : '127.0.0.1',
	'port' : 8000,
	"db" : "hangman.db"
}

class Hangman:
	pass

class HangmanAPI( http.server.BaseHTTPRequestHandler ):
	db = None
	def __init__( self, request, client_address, server ):
		self.db = sqlite3.connect( CONFIG['db'] )
		super().__init__( request, client_address, server )

	def __del__( self ):
		self.db.commit()
		self.db.close()

	def respondHTML( self, body, code=200 ):
		self.send_response( code )
		self.send_header("Content-Type", "text/html")
		self.end_headers()
		self.wfile.write( body.encode("utf-8") )

	def respondText( self, body, code=200 ):
		self.send_response( code )
		self.send_header("Content-Type", "text/plain")
		self.end_headers()
		self.wfile.write( body.encode("us-ascii") )

	def do_GET( self ):
		if "/" == self.path:
			self.respondHTML( open("hangman.html").read() )
		elif "/game" == self.path:
			self.respondText( "\n".join( [ x[0] for x in self.db.cursor().execute("Select * From game" ) ] ) )
		else:
			self.respondHTML( "<h1><code>500</code> ERROR</h1>", 500 )
	def do_POST( self ):
		if "/letter" == self.path:
			if "Content-Length" in self.headers:
				content_length = int(self.headers['Content-Length'])
			else:
				content_length = 0
			letter = json.loads( self.rfile.read(content_length) )['letter']
			self.db.cursor().execute( "Insert Into game Select ?", ( letter, ) )
			self.respondText( "OK" )
		else:
			self.respondHTML( "<h1><code>500</code> ERROR</h1>", 500 )

if __name__ == '__main__':
	print("Click here to play: http://%s:%d/" % ( CONFIG['addr'], CONFIG['port'] ) )
	http.server.HTTPServer( ( CONFIG['addr'], CONFIG['port'] ), HangmanAPI ).serve_forever()

