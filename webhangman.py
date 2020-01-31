#!/usr/bin/env python3

import http.server
import sqlite3
import json

CONFIG = {
	'addr' : '127.0.0.1',
	'port' : 8000,
	'db' : "hangman.db",
	'verbose' : True
}

class Hangman:
	def start_httpd( self ):
		print("Click here to play: http://%s:%d/" % ( CONFIG['addr'], CONFIG['port'] ) )
		http.server.HTTPServer( ( CONFIG['addr'], CONFIG['port'] ), HangmanAPI ).serve_forever()

class HangmanAPI( http.server.BaseHTTPRequestHandler ):
	db = None

	def __init__( self, request, client_address, server ):
		self.db = sqlite3.connect( CONFIG['db'] )
		super().__init__( request, client_address, server )

	def query_db( self, command, params=tuple() ):
		return self.db.cursor().execute( command, params )

	def __del__( self ):
		self.db.commit()
		self.db.close()

	def respond( self, body, contenttype, code=200, encoding="utf-8" ):
		self.send_response( code )
		self.send_header("Content-Type", contenttype )
		self.end_headers()
		self.writeresponse( body.encode( encoding ) )

	def respondHTML( self, body, code=200 ):
		self.respond( body, "text/html" )

	def respondText( self, body, code=200 ):
		self.respond( body, "text/plain" )

	def do_GET( self ):
		if "/" == self.path:
			self.respondHTML( open("hangman.html").read() )
		elif "/game" == self.path:
			self.respondText( "\n".join( [ x[0] for x in self.query_db("Select * From game" ) ] ) )
		else:
			self.respondHTML( "<h1><code>500</code> ERROR</h1>", 500 )

	def writeresponse( self, body ):
		self.wfile.write( body )

	def postdata( self ):
		content_length = int(self.headers['Content-Length']) if "Content-Length" in self.headers else 0
		return self.rfile.read( content_length )

	def do_POST( self ):
		if "/letter" == self.path:
			letter = json.loads( self.postdata() )['letter']
			self.query_db( "Insert Into game Select ?", ( letter, ) )
			self.respondText( "OK" )
		elif "/level" == self.path:
			level = json.loads( self.postdata() )['level']
			self.query_db( "Insert Or Replace Into level Select 1, ?", ( level, ) )
			self.respondText( "OK" )
		elif "/restart" == self.path:
			self.query_db( "Insert Into game Select 'start'" )
			self.respondText( "OK" )
		elif "/undo" == self.path:
			self.query_db( "Delete From guesses Where rowid = ( Select max(rowid) From guesses )" )
			self.respondText( "OK" )
		else:
			self.respondHTML( "<h1><code>500</code> ERROR</h1>", 500 )

if __name__ == '__main__':
	H = Hangman()
	H.start_httpd()

