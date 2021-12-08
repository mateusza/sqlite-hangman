#!/usr/bin/env python3

"""
Web service with Hangman game.
"""

import http.server
import sqlite3
import json

CONFIG = {
    'addr': '127.0.0.1',
    'port': 8009,
    'db': "hangman.db",
    'verbose': True
}


def start_hangman():
    """
    Starts the webservice with a game.
    """
    print("Click here to play: http://%s:%d/" %
          (CONFIG['addr'], CONFIG['port']))
    http.server.HTTPServer(
        (CONFIG['addr'], CONFIG['port']), HangmanAPI).serve_forever()


class HangmanAPI(http.server.BaseHTTPRequestHandler):
    """
    Hangman API
    """
    __db = None

    def __init__(self, request, client_address, server):
        self.__db = sqlite3.connect(CONFIG['db'])
        super().__init__(request, client_address, server)

    def query_db(self, command, params=tuple()):
        """
        Query local database
        """
        return self.__db.cursor().execute(command, params)

    def __del__(self):
        self.__db.commit()
        self.__db.close()

    def respond(self, body, contenttype, code=200, encoding="utf-8"):
        """
        Respond to HTTP request.
        """
        self.send_response(code)
        self.send_header("Content-Type", contenttype)
        self.end_headers()
        self.write_response(body.encode(encoding))

    def respond_html(self, body, code=200):
        """
        Respond with HTML
        """
        self.respond(body, "text/html", code=code)

    def respond_text(self, body, code=200):
        """
        Respond with plain/text
        """
        self.respond(body, "text/plain", code=code)

    def do_GET(self):
        # pylint: disable-msg=C0103
        """
        Handle GET request
        """
        if self.path == "/":
            self.respond_html(open("hangman.html").read())
        elif self.path == "/game":
            self.respond_text(
                "\n".join([x[0] for x in self.query_db("Select * From game")]))
        else:
            self.respond_html("<h1><code>500</code> ERROR</h1>", 500)

    def write_response(self, body):
        """
        Write response
        """
        self.wfile.write(body)

    def postdata(self):
        """
        Retrieve POST data
        """
        content_length = int(
            self.headers['Content-Length']) if "Content-Length" in self.headers else 0
        return self.rfile.read(content_length)

    def do_POST(self):
        # pylint: disable-msg=C0103
        """
        Handle POST request
        """
        if self.path == "/letter":
            letter = json.loads(self.postdata())['letter']
            self.query_db("Insert Into game Select ?", (letter, ))
            self.respond_text("OK")
        elif self.path == "/level":
            level = json.loads(self.postdata())['level']
            self.query_db(
                "Insert Or Replace Into level Select 1, ?", (level, ))
            self.respond_text("OK")
        elif self.path == "/restart":
            self.query_db("Insert Into game Select 'start'")
            self.respond_text("OK")
        elif self.path == "/undo":
            self.query_db(
                "Delete From guesses Where rowid = ( Select max(rowid) From guesses )")
            self.respond_text("OK")
        else:
            self.respond_html("<h1><code>500</code> ERROR</h1>", 500)


if __name__ == '__main__':
    start_hangman()
